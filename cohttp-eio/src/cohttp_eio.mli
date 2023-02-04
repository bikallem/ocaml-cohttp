module Body : sig
  type t =
    | Fixed of string
    | Chunked of chunk_writer
    | Custom of (Eio.Buf_write.t -> unit)
    | Empty

  and chunk_writer = {
    body_writer : (chunk -> unit) -> unit;
    trailer_writer : (Http.Header.t -> unit) -> unit;
  }

  (** [Chunk] encapsulates HTTP/1.1 chunk transfer encoding data structures.
      https://datatracker.ietf.org/doc/html/rfc7230#section-4.1 *)
  and chunk = Chunk of chunk_body | Last_chunk of chunk_extension list

  and chunk_body = {
    size : int;
    data : string;
    extensions : chunk_extension list;
  }

  and chunk_extension = { name : string; value : string option }

  val pp_chunk_extension : Format.formatter -> chunk_extension list -> unit
  val pp_chunk : Format.formatter -> chunk -> unit
end

module Body2 = Body2
module Method = Method
module Request = Request
module Response = Response
module Client2 = Client2
module Server = Server

(** [Client] is a HTTP/1.1 client. *)
module Client : sig
  type response = Http.Response.t * Eio.Buf_read.t

  type host = string
  (** Represents a server host - as ip address or domain name, e.g.
      www.example.org:8080, www.reddit.com*)

  type port = int
  (** Represents a tcp/ip port value *)

  type resource_path = string
  (** Represents HTTP request resource path, e.g. "/shop/purchase",
      "/shop/items", "/shop/categories/" etc. *)

  type 'a env = < net : Eio.Net.t ; .. > as 'a

  type ('a, 'b) body_disallowed_call =
    ?pipeline_requests:bool ->
    ?version:Http.Version.t ->
    ?headers:Http.Header.t ->
    ?conn:(#Eio.Flow.two_way as 'a) ->
    ?port:port ->
    'b env ->
    host:host ->
    resource_path ->
    response
  (** [body_disallowed_call] denotes HTTP client calls where a request is not
      allowed to have a request body.

      @param pipeline_requests
        If [true] then attempts to batch multiple client requests to improve
        request/reponse throughput. Set this to [false] if you want to improve
        latency of individual client request/response. Default is [false]. *)

  type ('a, 'b) body_allowed_call =
    ?pipeline_requests:bool ->
    ?version:Http.Version.t ->
    ?headers:Http.Header.t ->
    ?body:Body.t ->
    ?conn:(#Eio.Flow.two_way as 'a) ->
    ?port:port ->
    'b env ->
    host:host ->
    resource_path ->
    response
  (** [body_allowed_call] denotes HTTP client calls where a request can
      optionally have a request body.

      @param pipeline_requests
        If [true] then attempts to batch multiple client requests to improve
        request/reponse throughput. Set this to [false] if you want to improve
        latency of individual client request/response. Default is [false]. *)

  (** {1 Generic HTTP call} *)

  val call :
    ?pipeline_requests:bool ->
    ?meth:Http.Method.t ->
    ?version:Http.Version.t ->
    ?headers:Http.Header.t ->
    ?body:Body.t ->
    ?conn:#Eio.Flow.two_way ->
    ?port:port ->
    'a env ->
    host:host ->
    resource_path ->
    response

  (** {1 HTTP Calls with Body Disallowed} *)

  val get : ('a, 'b) body_disallowed_call
  val head : ('a, 'b) body_disallowed_call
  val delete : ('a, 'b) body_disallowed_call

  (** {1 HTTP Calls with Body Allowed} *)

  val post : ('a, 'b) body_allowed_call
  val put : ('a, 'b) body_allowed_call
  val patch : ('a, 'b) body_allowed_call

  (** {1 Response Body} *)

  val read_fixed : response -> string
  (** [read_fixed (response,reader)] is [body_content], where [body_content] is
      of length [n] if "Content-Length" header exists and is a valid integer
      value [n] in [response]. Otherwise [body_content] holds all bytes until
      eof. *)

  val read_chunked : response -> (Body.chunk -> unit) -> Http.Header.t option
  (** [read_chunked response chunk_handler] is [Some updated_headers] if
      "Transfer-Encoding" header value is "chunked" in [response] and all chunks
      in [reader] are read successfully. [updated_headers] is the updated
      headers as specified by the chunked encoding algorithm in https:
      //datatracker.ietf.org/doc/html/rfc7230#section-4.1.3.

      [reader] is updated to reflect the number of bytes read.

      Returns [None] if [Transfer-Encoding] header in [headers] is not specified
      as "chunked" *)
end
