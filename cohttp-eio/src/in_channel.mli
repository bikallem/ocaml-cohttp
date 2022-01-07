(** Buffered Input channel *)

type t

val of_flow : ?bufsize:int -> #Eio.Flow.read -> t
val fill_buf : t -> Cstruct.t * int * int
val consume : t -> int -> unit
val read_line : t -> string option
val read : t -> int -> string
