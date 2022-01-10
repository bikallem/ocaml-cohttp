type t
type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp_of]

val close : t -> unit

val create :
  ?backlog:int ->
  ?domains:int ->
  port:int ->
  error_handler:(Eio.Net.Sockaddr.t -> exn -> unit) ->
  (Eio.Std.Switch.t -> Eio.Net.Sockaddr.t -> Cohttp.Request.t -> unit) ->
  t

val run : t -> unit
