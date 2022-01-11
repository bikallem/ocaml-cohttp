type t
type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp_of]
type response_action = [ `Response of response ]

module Client_connection : sig
  type t

  val client_addr : t -> Eio.Net.Sockaddr.t
  val switch : t -> Eio.Std.Switch.t
  val close : t -> unit
end

val close : t -> unit

val create :
  ?backlog:int ->
  ?domains:int ->
  port:int ->
  error_handler:(Eio.Net.Sockaddr.t -> exn -> unit) ->
  (Client_connection.t -> Cohttp.Request.t -> response_action) ->
  t

val run : t -> unit
