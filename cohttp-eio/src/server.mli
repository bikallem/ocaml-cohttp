type t
and body = [ `String of Cstruct.t | `Chunked of unit -> chunk option ]
and chunk = { data : Cstruct.t; extensions : chunk_extension list }
and chunk_extension = { name : string; value : string option }

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
