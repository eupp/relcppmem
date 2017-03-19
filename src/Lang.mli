module type ATerm =
  sig
    (** Term type *)
    type t

    type lt'

    (** Injection of term into logic domain *)
    type lt = lt' MiniKanren.logic

    type ti = (t, lt) injected

    val inj : t -> lt
    val prj : lt -> t
    val show : t -> string
    (* val parse : string -> t *)
    val eq : t -> t -> bool
  end

module type AContext =
  sig
    (** Term type *)
    type t

    type lt'

    (** Injection of term into MiniKanren.logic domain *)
    type lt = lt' MiniKanren.logic

    type ti = (t, lt) injected

    (** Context type *)
    type c

    type lc'

    (** Injection of context into logic domain *)
    type lc = lc' MiniKanren.logic

    type ci = (c, lc) injected

    val inj : c -> lc
    val prj : lc -> c
    val show : c -> string
    val eq : c -> c -> bool

    (** [reducibleo t b] says whether term t could be reduced *)
    val reducibleo : lt -> bool MiniKanren.logic -> MiniKanren.goal

    (** [splito t c rdx] splits the term [t] into context [c] and redex [rdx] *)
    val splito :  lt ->  lc ->  lt -> MiniKanren.goal

    val plugo : lt -> lc -> lt -> MiniKanren.goal

  end

module type AState =
  sig
    type t

    type lt'

    type lt = lt' MiniKanren.logic

    type ti = (t, lt) injected

    val inj : t -> lt
    val prj : lt -> t
    val show : t -> string
    val eq : t -> t -> bool
  end

type loc   = string
type tstmp = int

type mem_order = SC | ACQ | REL | ACQ_REL | CON | RLX | NA

val string_of_loc : loc -> string
val string_of_tstmp : tstmp -> string
val string_of_mo : mem_order -> string

val mo_of_string : string -> mem_order

module Path :
  sig
    type 'a at = N | L of 'a | R of 'a

    type t  = t  at
    type lt = lt at MiniKanren.logic

    val inj : t -> lt
    val prj : lt -> t
  end

module Term :
  sig
    @type ('int, 'string, 'mo, 'loc, 't) at =
    | Const    of 'int
    | Var      of 'string
    | Binop    of 'string * 't * 't
    | Asgn     of 't * 't
    | Pair     of 't * 't
    | If       of 't * 't * 't
    | Repeat   of 't
    | Read     of 'mo * 'loc
    | Write    of 'mo * 'loc * 't
    | Cas      of 'mo * 'mo * 'loc * 't * 't
    | Seq      of 't * 't
    | Spw      of 't * 't
    | Par      of 't * 't
    | Skip
    | Stuck
    with gmap, eq, show

    type t   = (int, string, mem_order, loc, t) at
    type lt' = (MiniKanren.Nat.logic, string MiniKanren.logic, mem_order MiniKanren.logic, loc MiniKanren.logic, lt' MiniKanren.logic) at
    type lt  = lt' MiniKanren.logic
    type ti = (t, lt) injected

    val inj : t -> lt
    val prj : lt -> t
    val show : t -> string
    (* val parse : string -> t *)
    val eq : t -> t -> bool
  end

module Context :
  sig
    type t   = Term.t
    type lt' = Term.lt'
    type lt  = Term.lt
    type ti = (t, lt) injected

    @type ('expr, 'string, 'mo, 'loc, 't, 'c) ac =
    | Hole
    | BinopL    of 'string * 'c * 't
    | BinopR    of 'string * 't * 'c
    | PairL     of 'c * 't
    | PairR     of 't * 'c
    | AsgnC     of 't * 'c
    | WriteC    of 'mo * 'loc * 'c
    | IfC       of 'c * 't * 't
    | SeqC      of 'c * 't
    | ParL      of 'c * 't
    | ParR      of 't * 'c
    with gmap, eq, show

    type c   = (int, string, mem_order, loc, Term.t, c) ac
    type lc' = (MiniKanren.Nat.logic, string MiniKanren.logic, mem_order MiniKanren.logic, loc MiniKanren.logic, Term.lt, lc' MiniKanren.logic) ac
    type lc  = lc' MiniKanren.logic
    type ci = (c, ct) injected

    val inj : c -> lc

    val prj : lc -> c

    val show : c -> string

    val eq : c -> c -> bool

    val reducibleo : lt -> MiniKanren.Bool.logic -> MiniKanren.goal

    val splito : lt -> lc -> lt -> MiniKanren.goal

    val plugo : lt -> lc -> lt -> MiniKanren.goal

    val patho : lc -> Path.lt -> MiniKanren.goal
  end