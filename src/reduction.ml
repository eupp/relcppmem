
module type Context =
  sig
    type t
    
    type c

    type s
   
    type rresult = 
      | Skip
      | Conclusion of c * t * s

    type rule = (c * t * s -> rresult)
    
    val default_state : s    

    val split : t -> (c * t) list
    val plug : c * t -> t 
  end

module Interpreter (C : Context) =
  struct
    type t = (string * C.rule) list

    exception Rule_already_registered of string

    let create rules = rules

    let register_rule name rule rules = 
      if List.mem_assoc name rules 
      then raise (Rule_already_registered name) 
      else (name, rule)::rules

    let deregister_rule name rules = List.remove_assoc name rules

    let remove_duplicates xs = 
      let insert_unique ys x = 
        if List.exists ((=) x) ys
        then ys
        else x::ys
      in
           List.fold_left insert_unique [] xs  
        |> List.rev
        
    let apply_rule (c, t) s rule =
      match (rule (c, t, s)) with 
        | C.Conclusion (c', t', s') -> [(c', t', s')]
        | C.Skip                -> []

    let apply_rules ((c, t) as redex) s rules =
      let res = 
           List.map (fun (_, rule) -> apply_rule redex s rule) rules 
        |> List.concat
        |> remove_duplicates
      in
        if res = [] then [(c, t, s)] else res

    let step rules (t, s) =
      let redexes = C.split t in
           List.map (fun redex -> apply_rules redex s rules) redexes
        |> List.concat
        |> List.map (fun (c', t', s') -> C.plug (c', t'), s')
      
    let rec space' rules cfgs = 
      let next =
           List.map (step rules) cfgs 
        |> List.concat
      in
        if next = cfgs
        then cfgs
        else space' rules next
    
    let space rules cfg = space' rules [cfg]
       
  end
