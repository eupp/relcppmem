
module Expr = 
  struct
    type t = 
      | Const    of int
      | Var      of string
      | Binop    of string * t * t
      | Stuck

    let is_value = function
      | Const _ -> true
      | _       -> false

    let is_var = function
      | Var _ -> true
      | _     -> false
  end

module ExprContext = 
  struct
    type t = Expr.t

    type c =
      | Hole
      | BinopL   of string * c * t
      | BinopR   of string * t * c 

    type s = Memory.StateST.t

    type rresult =
      | Conclusion of c * t * s
      | Rewrite    of t * s 
      | Skip

    type rule = (c * t * s -> rresult list)

    let default_state = Memory.StateST.empty

    let rec split = 
      let module E = Expr in 
        function
          | E.Binop (op, x, y) as t when E.is_value x && E.is_value y -> [Hole, t]
          | E.Binop (op, x, y)      when E.is_value x                 ->
              List.map (fun (c, t) -> BinopR (op, x, c), t) (split y)
          | E.Binop (op, x, y)                                        ->
              List.map (fun (c, t) -> BinopL (op, c, y), t) (split x)
          | t -> [Hole, t]

    let rec plug (c, t) = 
      let module E = Expr in 
        match c with
          | Hole                        -> t
          | BinopL (op, c', t')         -> E.Binop (op, plug (c', t), t')
          | BinopR (op, t', c')         -> E.Binop (op, t', plug (c', t))
  end

module Stmt = 
  struct
    type t =
      | AExpr    of Expr.t
      | Asgn     of t * t
      | If       of Expr.t * t * t
      | Repeat   of Expr.t
      | Read     of Memory.mem_order * Memory.loc
      | Write    of Memory.mem_order * Memory.loc * Expr.t
      | Cas      of Memory.mem_order * Memory.mem_order * Memory.loc * Expr.t * Expr.t
      | Seq      of t * t
      | Spw      of t * t
      | Par      of t * t
      | Skip
      | Stuck

    let is_value = function
      | AExpr e   -> Expr.is_value e 
      | _         -> false

    let is_var = function
      | AExpr e   -> Expr.is_var e
      | _         -> false
  end

module StmtContext = 
  struct
    type t = Stmt.t

    type c =
      | Hole
      | AsgnL    of c * t
      | AsgnR    of t * c
      | Seq      of c * t
      | ParL     of c * t
      | ParR     of t * c

    type s = Memory.StateMT.t

    type rresult =
      | Conclusion of c * t * s 
      | Rewrite    of t * s
      | Skip

    type rule = (c * t * s -> rresult list)

    let default_state = Memory.StateMT.empty

    let rec split = 
      let module E = Expr in
      let module S = Stmt in 
        function
          | S.Asgn    (x, y) as t when S.is_var x && S.is_value y -> [Hole, t]
          | S.Asgn    (x, y) as t when S.is_var x                 ->
              List.map (fun (c, t) -> AsgnR (x, c), t) (split y)
          | S.Asgn    (x, y)                                      ->
              List.map (fun (c, t) -> AsgnL (c, y), t) (split x)

          | S.Seq (S.Skip, y) as t -> [Hole, t]
          | S.Seq (x, y)           ->
              List.map (fun (c, t) -> Seq (c, y), t) (split x)

          | S.Par  (l, r) as t ->
             let lcontexts = List.map (fun (c, t) -> ParL (c, r), t) (split l) in
             let rcontexts = List.map (fun (c, t) -> ParR (l, c), t) (split r) in
             (match S.is_value l, S.is_value r with
                | false, false -> lcontexts @ rcontexts
                | _    , false -> rcontexts
                | false, _     -> lcontexts
                | _            -> [Hole, t]
             )

          | t -> [Hole, t]

    let rec plug (c, t) =
      let module S = Stmt in
      let module EC = ExprContext in
        match c with
          | Hole                         -> t
          
          | AsgnL  (c', t')              -> S.Asgn (plug (c', t), t')
          | AsgnR  (t', c')              -> S.Asgn (t', plug (c', t))

          | Seq  (c', t')                -> S.Seq (plug (c', t), t')
          | ParL (c', t')                -> S.Par (plug (c', t), t')
          | ParR (t', c')                -> S.Par (t', plug (c', t))

    let rec get_path = function
      | Hole -> Memory.Path.N

      | AsgnL   (c, _)
      | AsgnR   (_, c)
      | Seq     (c, _)
        -> get_path c

      | ParL    (c, _) -> Memory.Path.L (get_path c)
      | ParR    (_, c) -> Memory.Path.R (get_path c) 
  end