module E  = Lang.Expr
module EC = Lang.ExprContext 

module S  = Lang.Stmt
module SC = Lang.StmtContext

module SST   = Memory.StateST
module SMT   = Memory.StateMT 
module VF    = Memory.ViewFront
module H     = Memory.History
module T     = Memory.ThreadState
module TTree = Memory.ThreadTree 

module ExprIntpr = Reduction.Interpreter(EC)

module BasicExpr = 
  struct
    type t = EC.t

    type c = EC.c

    type s = EC.s   

    type rresult = EC.rresult

    let get_value = function
      | E.Const n -> n
      (*| Expr.Var x   -> ExprContext.lookup_var s x*)
      | _            -> failwith "Given term is not a value-term" 

    let read_na' c s var =
      let h            = s.SST.history in
      let thrd         = s.SST.thread in
      let tm           = H.last_tstmp var h in
      let (_, _, v, _) = H.get var tm h in
        if tm = VF.get var thrd.T.curr
        then EC.Conclusion (c, E.Const v, s)
        else EC.Rewrite (E.Stuck, s)

    let var (c, t, s) = 
      match t with
        | E.Var var -> [read_na' c s var]
        | _         -> [EC.Skip]

    let apply_binop op l r =
      let l' = get_value l in
      let r' = get_value r in
        match op with
          | "+" -> E.Const (l' + r')
          | "-" -> E.Const (l' - r')
          | "*" -> E.Const (l' * r')
          | _   -> failwith "Unsupported binary operator"        

    let binop (c, t, s) = 
      match t with
        | E.Binop (op, l, r) -> [EC.Conclusion (c, apply_binop op l r, s)]
        | _                  -> [EC.Skip]  
  end

module BasicStmt = 
  struct 
    type t = SC.t

    type c = SC.c

    type s = SC.s   

    type rresult = SC.rresult

    let expr_rules = ExprIntpr.create [
      "read_na", BasicExpr.var;
      "binop"  , BasicExpr.binop;
    ]
    
    let write_na' c s var v = 
      let h     = s.SMT.history in
      let ttree = s.SMT.tree in
      let tm    = H.last_tstmp var h in
      let thrd  = TTree.get_thread ttree (SC.get_path c) in
        if tm = VF.get var thrd.T.curr
        then 
          let tm'      = tm + 1 in
          let h'       = H.insert var tm' v VF.empty h in
          let thrd'    = {thrd with T.curr = VF.update var tm' thrd.T.curr} in
          let ttree'   = TTree.update_thread ttree (SC.get_path c) thrd' in
            SC.Conclusion (c, S.Skip, { SMT.history = h'; SMT.tree = ttree'; })
        else 
          SC.Rewrite (S.Stuck, s)

    let read_na (c, t, s) = 
      match t with
        | S.Read (Memory.NA, loc) -> 
          let path = SC.get_path c in
          let thrd = TTree.get_thread s.SMT.tree path in
            begin
              match BasicExpr.read_na' EC.Hole {SST.history = s.SMT.history; SST.thread = thrd;} loc with
                | EC.Conclusion (c', e, s') -> [SC.Conclusion (c, S.AExpr e, s)]
                | EC.Rewrite (E.Stuck, s')  -> [SC.Rewrite (S.Stuck, s)]
            end
        | _                     -> [SC.Skip]

    let write_na (c, t, s) = 
      let path = SC.get_path c in
      let thrd = TTree.get_thread s.SMT.tree path in
        match t with
          | S.Write (Memory.NA, loc, e) ->
               ExprIntpr.space expr_rules (e, {SST.history = s.SMT.history; SST.thread = thrd;})
            |> List.map (fun (E.Const v, s') -> write_na' c s loc v) 
          | _                         -> [SC.Skip]
             
    let assign' c s el er =
      match (el, er) with
        | (E.Var var, E.Const v) -> write_na' c s var v
        | _                      -> failwith "Bad assignment"

    let assign (c, t, s) = 
      let path = SC.get_path c in
      let thrd = TTree.get_thread s.SMT.tree path in
      let es = {SST.history = s.SMT.history; SST.thread = thrd;} in
        match t with
          | S.Asgn (S.AExpr el, S.AExpr er) -> 
                ExprIntpr.space expr_rules (el, es)
             |> List.map (fun (el', _) -> 
                  List.map (fun (er', _) -> assign' c s el' er') (ExprIntpr.space expr_rules (er, es)))
             |> List.concat

          | _                               -> [SC.Skip]

    let if' (c, t, s) = 
      let path = SC.get_path c in
      let thrd = TTree.get_thread s.SMT.tree path in
        match t with 
          | S.If (cond, tbranch, fbranch) ->
               ExprIntpr.space expr_rules (cond, {SST.history = s.SMT.history; SST.thread = thrd;})
            |> List.map (fun (E.Const x, _) -> if x <> 0 then [SC.Conclusion (c, tbranch, s)] else [SC.Conclusion (c, fbranch, s)])
            |> List.concat                 
          | _                             -> [SC.Skip] 

    let repeat (c, t, s) = 
      let path = SC.get_path c in
      let thrd = TTree.get_thread s.SMT.tree path in
        match t with 
          | S.Repeat e -> 
               ExprIntpr.space expr_rules (e, {SST.history = s.SMT.history; SST.thread = thrd;})
            |> List.map (fun (E.Const x, _) -> if x <> 0 then [SC.Conclusion (c, S.Repeat e, s)] else [SC.Conclusion (c, S.Skip, s)])
            |> List.concat
          | _          -> [SC.Skip] 
          
    
  end