(* Copyright (c) 2016-2018
 * Evgenii Moiseenko and Anton Podkopaev
 * St.Petersburg State University, JetBrains Research
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

open MiniKanren

open Lang
open Lang.Expr
open Lang.Stmt
open Lang.Loc
open Lang.Reg
open Lang.Value

let prog_MP h1 h2 = <:cppmem_par<
  spw {{{
    x_na := 1;
    ? h1
  |||
    ? h2;
    r2 := x_na
  }}}
>>

module SeqCstTest = Test.OperationalTest(Operational.RelAcq)

let regs = ["r1"; "r2"]
let locs = ["x"; "f"]

let istate_MPo s =
  fresh (h1 h2 mo1 mo2)
    (s  === SeqCstTest.make_istate ~regs ~locs @@ prog_MP h1 h2)
    (* (h1 === store mo1 (loc "f") (const @@ integer 1)) *)
    (* (h2 === repeat (single @@ load mo2 (loc "f") (reg "r1")) (var @@ reg "r1")) *)

let test_MP =
  SeqCstTest.test_synth
    ~name:"MP"
    ~prop:Prop.(
      (2%"r2" = 1)
    )
    istate_MPo

let tests_sc_op =
  Test.(make_testsuite ~name:"Synth" ~tests: [
    make_testcase ~name:"MP" ~test:fun () -> test_MP
  ])

let tests = Test.(
  make_testsuite ~name:"Synth" ~tests: [
    make_testsuite ~name:"Operational" ~tests: [
      tests_sc_op;
      (* tests_tso_op; *)
      (* tests_ra_op; *)
    ];


  ]
)
