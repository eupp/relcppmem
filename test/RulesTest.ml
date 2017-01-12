open OUnit2
open MiniKanren
open Memory
open Rules

module ET = Lang.ExprTerm
module EC = Lang.ExprContext
module ES = Lang.ExprState

module ST = Lang.StmtTerm
module SC = Lang.StmtContext
module SS = Lang.StmtState

module Tester 
  (T : Lang.Term)
  (C : Lang.Context with type t = T.t with type lt' = T.lt')
  (S : Lang.State) = 
  struct 
    module Sem = Semantics.Make(T)(C)(S)

    let show (t, s) = "Term/State is not found among answers: " ^ T.show t ^ "; " ^ S.show s
      
    let eq (t, s) (t', s') = (T.eq t t') && (S.eq s s')

    let test_step ?empty_check rules (t, s) expected test_ctx =
      let sem    = Sem.make rules in
      let stream = Sem.step sem t s in
        TestUtils.assert_stream ?empty_check stream expected ~show:show ~eq:eq

    let test_space ?empty_check rules (t, s) expected test_ctx = 
      let sem    = Sem.make rules in
      let stream = Sem.space sem t s in
        TestUtils.assert_stream ?empty_check stream expected ~show:show ~eq:eq 
  end
  
module ExprTester = Tester(ET)(EC)(ES)
module StmtTester = Tester(ST)(SC)(SS)

let basic_expr_tests = 

  let regs = Registers.set "x" 42 Registers.empty in
  let thrd = { ThreadState.regs = regs; ThreadState.curr = ViewFront.empty } in

  "basic_expr">::: [
    "var">:: ExprTester.test_step [BasicExpr.var] (ET.Var "x", thrd) [(ET.Const 42, thrd)];
    
    "binop">:: ExprTester.test_step [BasicExpr.binop] (ET.Binop ("+", ET.Const 1, ET.Const 2), thrd) [(ET.Const 3, thrd)];

    "step_all">:: ExprTester.test_step BasicExpr.all (ET.Binop ("+", ET.Var "x", ET.Const 1), thrd) [(ET.Binop ("+", ET.Const 42, ET.Const 1), thrd)];


    "space_all">:: let
               e = (ET.Binop ("+", ET.Var "x", ET.Binop ("*", ET.Const 2, ET.Const 4)), thrd)
             in
               ExprTester.test_space BasicExpr.all e [(ET.Const 50, thrd); (ET.Const 50, thrd)];
  ]

let basic_stmt_tests = 
  
  let mem  = MemState.assign_local Path.N "x" 42 MemState.empty in 
  let mem' = MemState.assign_local Path.N "y" 1 mem in 

  "basic_stmt">::: [
    "expr">:: StmtTester.test_step [BasicStmt.expr] (ST.AExpr (ET.Var "x"), mem) [(ST.AExpr (ET.Const 42), mem)];

    "pair">:: StmtTester.test_step [BasicStmt.pair] (ST.Pair (ET.Var "x", ET.Var "y"), mem') [(ST.Pair (ET.Const 42, ET.Const 1), mem')];

    "assign">:: StmtTester.test_step [BasicStmt.asgn] (ST.Asgn (ST.AExpr (ET.Var "x"), ST.AExpr (ET.Const 42)), MemState.empty) [(ST.Skip, mem)];

    "if_true">:: StmtTester.test_step ~empty_check:false [BasicStmt.if'] (ST.If (ST.AExpr (ET.Const 1), ST.Skip, ST.Stuck), mem) [(ST.Skip, mem)];

    "if_false">:: StmtTester.test_step ~empty_check:false [BasicStmt.if'] (ST.If (ST.AExpr (ET.Const 0), ST.Stuck, ST.Skip), mem) [(ST.Skip, mem)];

    "repeat">:: (let loop = ST.Repeat (ST.AExpr (ET.Const 1)) in
                  StmtTester.test_step ~empty_check:false [BasicStmt.repeat] (loop, mem) [(ST.If (ST.AExpr (ET.Const 1), loop, ST.Skip), mem)]);

    "seq_skip">:: StmtTester.test_step [BasicStmt.seq] (ST.Seq (ST.Skip, ST.Skip), mem) [(ST.Skip, mem)];

    "seq_stuck">:: StmtTester.test_step [BasicStmt.seq] (ST.Seq (ST.Stuck, ST.Skip), mem) [(ST.Stuck, mem)];

    "spawn">:: (let leaf = ThreadTree.Leaf ThreadState.empty in
                let thrd_tree = ThreadTree.Node (leaf, leaf) in
                let state  = { MemState.thrds = leaf; MemState.story = MemStory.empty; } in
                let state' = { MemState.thrds = thrd_tree; MemState.story = MemStory.empty } in
                  StmtTester.test_step [BasicStmt.spawn] (ST.Spw (ST.Skip, ST.Skip), state) [(ST.Par (ST.Skip, ST.Skip), state')]);

    "join">::  (let leaf = ThreadTree.Leaf ThreadState.empty in
                let thrd_tree = ThreadTree.Node (leaf, leaf) in
                let state  = { MemState.thrds = thrd_tree;  MemState.story = MemStory.empty; } in
                let state' = { MemState.thrds = leaf;  MemState.story = MemStory.empty; } in
                  StmtTester.test_step [BasicStmt.join] (ST.Par (ST.AExpr (ET.Const 1), ST.AExpr (ET.Const 2)), state) [(ST.Pair (ET.Const 1, ET.Const 2), state')]);

    "spawn_assign">:: (let pair = ST.Pair (ET.Var "x", ET.Var "y") in
                       let stmt = ST.Asgn (pair,ST.Spw (
                           ST.AExpr (ET.Const 42),
                           ST.AExpr (ET.Const 1)
                         )) in
                         StmtTester.test_space BasicStmt.all (stmt, MemState.empty) [(ST.Skip, mem')]);

    "seq_asgn">:: (let stmt = ST.Seq ((ST.Asgn (ST.AExpr (ET.Var "x"), ST.AExpr (ET.Const 42)), ST.AExpr (ET.Var "x"))) in
                     StmtTester.test_space BasicStmt.all (stmt, MemState.empty) [(ST.AExpr (ET.Const 42), mem)]);

    "space_all">:: (let pair = ST.Pair (ET.Var "x", ET.Var "y") in
                    let stmt = ST.Seq (ST.Asgn (pair, ST.Spw (
                      ST.Seq ((ST.Asgn (ST.AExpr (ET.Var "z"), ST.AExpr (ET.Const 42)), ST.AExpr (ET.Var "z"))),
                      ST.If (ST.AExpr (ET.Const 1), ST.AExpr (ET.Const 1), ST.AExpr (ET.Const 0)) 
                   )), pair) in
                      StmtTester.test_space ~empty_check:false BasicStmt.all (stmt, MemState.empty) [(ST.Pair (ET.Const 42, ET.Const 1), mem')]);
                   
  ]

let rel_acq_tests =

  let vf         = ViewFront.from_assoc [("x", 0)] in
  let vf'        = ViewFront.from_assoc [("x", 1)] in
  let thrd       = { ThreadState.regs = Registers.empty; ThreadState.curr = vf; } in
  let thrd'      = { ThreadState.regs = Registers.empty; ThreadState.curr = vf'; } in
  let thrd_tree  = ThreadTree.Leaf thrd in
  let thrd_tree' = ThreadTree.Leaf thrd' in
 
  "rel_acq">::: [
    "read_acq">:: 
      (let mem_story = MemStory.from_assoc [("x", LocStory.from_list [(0, 0, vf); (1, 1, vf')])] in
       let state     = { MemState.thrds = thrd_tree; MemState.story = mem_story; } in
       let state'    = { MemState.thrds = thrd_tree'; MemState.story = mem_story; } in
         StmtTester.test_step ~empty_check:false [RelAcq.read_acq] (ST.Read (ACQ, "x"), state) [(ST.AExpr (ET.Const 0), state); (ST.AExpr (ET.Const 1), state')]);

    "write_rel">:: 
      (let mem_story  = MemStory.from_assoc [("x", LocStory.from_list [(0, 0, vf)])] in
       let mem_story' = MemStory.from_assoc [("x", LocStory.from_list [(0, 0, vf); (1, 1, vf')])] in
       let state      = { MemState.thrds = thrd_tree; MemState.story = mem_story; } in
       let state'     = { MemState.thrds = thrd_tree'; MemState.story = mem_story'; } in
         StmtTester.test_step [RelAcq.write_rel] (ST.Write (REL, "x", ET.Const 1), state) [(ST.Skip, state')]);
 
  ]

let tests = 
  "rules">::: [basic_expr_tests; basic_stmt_tests; rel_acq_tests]
