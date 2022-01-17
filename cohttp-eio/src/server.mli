type t

type response =
  [ `Response of Cohttp.Response.t * Cohttp.Body.t
  | `Expert of Cohttp.Response.t * (In_channel.t -> Eio.Flow.write -> unit) ]

module Client_connection : sig
  type t

  val client_addr : t -> Eio.Net.Sockaddr.t
  val switch : t -> Eio.Std.Switch.t
  val close : t -> unit
end

val create :
  ?backlog:int ->
  ?domains:int ->
  ?chunkstream_backlog:int ->
  port:int ->
  error_handler:(Eio.Net.Sockaddr.t -> exn -> unit) ->
  (Client_connection.t -> Cohttp.Request.t * Body.t -> response) ->
  t

val run : t -> unit
val close : t -> unit
