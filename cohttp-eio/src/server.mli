type t
type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp_of]

val close : t -> unit

val run :
  ?backlog:int ->
  port:int ->
  on_error:(Eio.Net.Sockaddr.t -> exn -> unit) ->
  (Eio.Std.Switch.t -> Eio.Net.Sockaddr.t -> Cohttp.Request.t -> unit) ->
  unit
