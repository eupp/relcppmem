
(** Type of graph *)
type ('v, 'e) t

exception Duplicate_vertex
exception Duplicate_edge

val create : unit -> ('v, 'e) t

val add_vertex : ('v, 'e) t -> 'v -> unit

val connect : ('v, 'e) t -> 'v -> 'v -> 'e -> unit
val disconnect : ('v, 'e) t -> 'v -> 'v -> unit

val outdegree : ('v, 'e) t -> 'v -> int 

val sinks : ('v, 'e) t -> 'v list

val iter_vertices :  ('v, 'e) t -> ('v -> unit) -> unit
val iter_neighbors : ('v, 'e) t -> 'v -> ('v * 'e -> unit) -> unit  
