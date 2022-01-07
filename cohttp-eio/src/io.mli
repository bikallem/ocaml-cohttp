type +'a t
type ic = In_channel.t
type oc = Eio.Flow.write
type conn = Eio.Flow.two_way
type error = exn

val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
val return : 'a -> 'a t
val read_line : ic -> string option t
val read : ic -> int -> string t
val write : oc -> string -> unit t
val flush : oc -> unit t
val catch : (unit -> 'a t) -> ('a, error) result t
val pp_error : Format.formatter -> error -> unit
