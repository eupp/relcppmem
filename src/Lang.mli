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

module Reg :
  sig
    include Utils.Logic

    val reg : string -> ti

    val show : tl -> string
  end

module Loc :
  sig
    include Utils.Logic

    val loc : string -> ti

    val show : tl -> string
  end

module Value :
  sig
    include Utils.Logic

    val integer : int -> ti

    val show : tl -> string

    val nullo     : ti -> MiniKanren.goal
    val not_nullo : ti -> MiniKanren.goal

    val addo : ti -> ti -> ti -> MiniKanren.goal
    val mulo : ti -> ti -> ti -> MiniKanren.goal

    val eqo : ti -> ti -> MiniKanren.goal
    val nqo : ti -> ti -> MiniKanren.goal
    val lto : ti -> ti -> MiniKanren.goal
    val leo : ti -> ti -> MiniKanren.goal
    val gto : ti -> ti -> MiniKanren.goal
    val geo : ti -> ti -> MiniKanren.goal
  end

module MemOrder :
  sig
    type tt = SC | ACQ | REL | ACQ_REL | CON | RLX | NA

    type tl = tt MiniKanren.logic

    type ti = (tt, tl) MiniKanren.injected

    val mo : string -> ti

    val reify : MiniKanren.helper -> ti -> tl

    val show : tl -> string
  end

module Regs :
  sig
    include Utils.Logic

    val empty : unit -> ti

    val alloc : string list -> ti
    val init : (string * int) list -> ti

    val reado  : ti ->       Reg.ti -> Value.ti -> MiniKanren.goal
    val writeo : ti -> ti -> Reg.ti -> Value.ti -> MiniKanren.goal

    val checko : ti -> (string * int) list -> MiniKanren.goal
  end

module Uop :
  sig
    type tt

    type tl = tt MiniKanren.logic

    type ti = (tt, tl) MiniKanren.injected

    val uop : string -> ti

    val reify : MiniKanren.helper -> ti -> tl

    val show : tl -> string
  end

module Bop :
  sig
    type tt

    type tl = tt MiniKanren.logic

    type ti = (tt, tl) MiniKanren.injected

    val bop : string -> ti

    val reify : MiniKanren.helper -> ti -> tl

    val show : tl -> string
  end

module ThreadID :
  sig
    include Utils.Logic

    val tid : int -> ti

    val null : ti
    val init : ti
  end

module Expr :
  sig
    include Utils.Logic

    val var       : Reg.ti -> ti
    val const     : Value.ti -> ti
    val unop      : Uop.ti -> ti -> ti
    val binop     : Bop.ti -> ti -> ti -> ti
    val choice    : ti -> ti -> ti

    val show : tl -> string
  end

module Prog :
  sig
    include Utils.Logic
  end

module Stmt :
  sig
    include Utils.Logic

    (* val skip      : unit -> ti *)
    val assertion : Expr.ti -> ti
    val asgn      : Reg.ti -> Expr.ti -> ti
    val if'       : Expr.ti -> Prog.ti -> Prog.ti -> ti
    val while'    : Expr.ti -> Prog.ti -> ti
    val repeat    : Prog.ti -> Expr.ti -> ti
    val load      : MemOrder.ti -> Loc.ti -> Reg.ti -> ti
    val store     : MemOrder.ti -> Loc.ti -> Expr.ti     -> ti
    val cas       : MemOrder.ti -> MemOrder.ti -> Loc.ti -> Expr.ti -> Expr.ti -> Reg.ti -> ti
    val spw       : Prog.ti -> Prog.ti -> ti
    val return    : (Reg.tt, Reg.tl) MiniKanren.Std.List.groundi -> ti

    val show : tl -> string
  end

module CProg :
  sig
    include Utils.Logic
  end

val prog  : Stmt.ti list -> Prog.ti
val cprog : Prog.ti list -> CProg.ti

val thrdnum : CProg.ti -> int

module Error :
  sig
    include Utils.Logic

    type code = Assertion | Datarace

    val assertion : Expr.ti -> ti
    val datarace  : MemOrder.ti -> Loc.ti -> ti

    val errcodeo : code -> ti -> MiniKanren.goal
  end

module Label :
  sig
    include Utils.Logic

    val empty : unit -> ti

    val load  : MemOrder.ti -> Loc.ti -> Value.ti -> ti
    val store : MemOrder.ti -> Loc.ti -> Value.ti -> ti

    val cas : MemOrder.ti -> MemOrder.ti -> Loc.ti -> Value.ti -> Value.ti -> Value.ti -> ti

    val error : Error.ti -> ti

    val erroro :
      ?sg:(Error.ti -> MiniKanren.goal) ->
      ?fg:MiniKanren.goal ->
      ti -> MiniKanren.goal
  end

module ThreadLocalStorage(T : Utils.Logic) :
  sig
    include Utils.Logic

    val init : int -> T.ti -> ti
    val initi : int -> (ThreadID.ti -> T.ti) -> ti
    val of_list : T.ti list -> ti

    val geto : ti       -> ThreadID.ti -> T.ti -> MiniKanren.goal
    val seto : ti -> ti -> ThreadID.ti -> T.ti -> MiniKanren.goal

    val tidso : ti -> (ThreadID.tt, ThreadID.tl) MiniKanren.Std.List.groundi -> MiniKanren.goal

    val foldo :
      (T.ti -> ('at, _ MiniKanren.logic as 'al) MiniKanren.injected -> ('at, 'al) MiniKanren.injected -> MiniKanren.goal) ->
      ti -> ('at, 'al) MiniKanren.injected -> ('at, 'al) MiniKanren.injected -> MiniKanren.goal

    val forallo : (T.ti -> MiniKanren.goal) -> ti -> MiniKanren.goal
  end

module Thread :
  sig
    include Utils.Logic

    val init : ?pid:ThreadID.ti -> Prog.ti -> Regs.ti -> ti

    val terminatedo : ti -> MiniKanren.goal
  end

module ThreadManager :
  sig
    include module type of ThreadLocalStorage(Thread)

    val init : Prog.ti list -> Regs.ti list -> ti

    val terminatedo : ti -> MiniKanren.goal

    val stepo : ThreadID.ti -> Label.ti -> ti -> ti -> MiniKanren.goal
  end
