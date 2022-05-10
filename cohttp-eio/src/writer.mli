type t

val create : Eio.Flow.sink -> t
val write_string : t -> string -> unit
val write : t -> Http.Response.t * Body.t -> unit
val wakeup : t -> unit
val run : t -> unit
