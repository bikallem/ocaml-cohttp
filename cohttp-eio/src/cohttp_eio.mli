(** [Reader] is a buffered reader with back-tracking support. *)
module Reader : sig
  type t

  exception Parse_failure of string

  type 'a parser = t -> 'a

  val create : int -> Eio.Flow.source -> t

  val length : t -> int
  (** [length t] is the count of unconsumed bytes in [t]. *)

  val consume : t -> int -> unit
  (** [consume t n] marks [n] bytes of data as consumed in [t]. *)

  val fill : t -> int -> int
  (** [fill t n] attempts to fill [t] with [n] bytes and returns the actual
      number of bytes filled.

      @raise End_of_file if end of file is reached. *)

  val unsafe_get : t -> int -> char
  val substring : t -> off:int -> len:int -> string
  val copy : t -> off:int -> len:int -> Bigstringaf.t

  (** {1 Parser/Reader Combinators} *)

  val return : 'a -> 'a parser
  val fail : string -> 'a parser
  val commit : unit parser
  val pos : int parser
  val ( <?> ) : 'a parser -> string -> 'a parser
  val ( >>= ) : 'a parser -> ('a -> 'b parser) -> 'b parser
  val ( let* ) : 'a parser -> ('a -> 'b parser) -> 'b parser
  val ( >>| ) : 'a parser -> ('a -> 'b) -> 'b parser
  val ( let+ ) : 'a parser -> ('a -> 'b) -> 'b parser
  val ( <* ) : 'a parser -> _ parser -> 'a parser
  val ( *> ) : _ parser -> 'b parser -> 'b parser
  val ( <|> ) : 'a parser -> 'a parser -> 'a parser
  val lift : ('a -> 'b) -> 'a parser -> 'b parser
  val lift2 : ('a -> 'b -> 'c) -> 'a parser -> 'b parser -> 'c parser
  val end_of_input : bool parser
  val option : 'a -> 'a parser -> 'a parser
  val peek_char : char parser
  val peek_string : int -> string parser
  val char : char -> unit parser
  val any_char : char parser
  val satisfy : (char -> bool) -> char parser
  val string : string -> unit parser
  val take_while1 : (char -> bool) -> string parser
  val take_while : (char -> bool) -> string parser
  val take_bigstring : int -> Bigstringaf.t parser
  val take : int -> string parser
  val take_till : (char -> bool) -> string parser
  val many : 'a parser -> 'a list parser
  val many_till : 'a parser -> _ parser -> 'a list parser
  val skip : (char -> bool) -> unit parser
  val skip_while : (char -> bool) -> unit parser
  val skip_many : 'a parser -> unit parser
end

(** [Server] is a HTTP 1.1 server. *)
module Server : sig
  (** [Chunk] encapsulates HTTP/1.1 chunk transfer encoding data structures.
      https://datatracker.ietf.org/doc/html/rfc7230#section-4.1 *)
  module Chunk : sig
    type t = Chunk of chunk | Last_chunk of extension list
    and chunk = { size : int; data : Cstruct.t; extensions : extension list }
    and extension = { name : string; value : string option }

    val pp : Format.formatter -> t -> unit
  end

  (** [Request] is a HTTP/1.1 request. *)
  module Request : sig
    type t

    (** {1 Request Details} *)

    val headers : t -> Http.Header.t
    val meth : t -> Http.Method.t
    val resource : t -> string
    val version : t -> Http.Version.t
    val is_keep_alive : t -> bool

    (** {1 Builtin Request Body Readers} *)

    val read_fixed : t -> (string, string) result
    (** [read_fixed t] is [Ok buf] if "Content-Length" header is a valid integer
        value in [t]. Otherwise it is [Error err] where [err] is the error text. *)

    val read_chunk : t -> (Chunk.t -> unit) -> (t, string) result
    (** [read_chunk t f] is [Ok req] if "Transfer-Encoding" header value is
        "chunked" in [t] and all chunks in a request are read successfully.
        [req] is the updated request as specified by the chunked encoding
        algorithm in
        https://datatracker.ietf.org/doc/html/rfc7230#section-4.1.3. Otherwise
        it is [Error err] where [err] is the error text. *)

    (** {1 Custom Request Body Readers} *)

    val reader : t -> Reader.t
    (** [reader t] returns a [Reader.t] instance. This can be used to create a
        custom request body reader. *)

    (** {1 Pretty Printer} *)

    val pp : Format.formatter -> t -> unit
  end

  (** [Response] is a HTTP/1.1 response. *)
  module Response : sig
    type t

    and body =
      | String of string
      | Chunked of write_chunk
      | Custom of (Eio.Flow.sink -> unit)
      | Empty

    and write_chunk = (Chunk.t -> unit) -> unit

    (** {1 Response Details} *)

    val headers : t -> Http.Header.t
    val status : t -> Http.Status.t
    val body : t -> body

    (** {1 Configuring Basic Response} *)

    val create :
      ?version:Http.Version.t ->
      ?status:Http.Status.t ->
      ?headers:Http.Header.t ->
      body ->
      t
    (** [create body] returns a HTTP/1.1, 200 status response with no headers. *)

    val text : string -> t
    (** [text t s] returns a HTTP/1.1, 200 status response with "Content-Type"
        header set to "text/plain". *)

    val html : string -> t
    (** [html t s] returns a HTTP/1.1, 200 status response with header set to
        "Content-Type: text/html". *)

    val not_found : t
    (** [not_found t] returns a HTTP/1.1, 404 status response. *)

    val internal_server_error : t
    (** [internal_server_error] returns a HTTP/1.1, 500 status response. *)

    val bad_request : t
    (** [bad_request t] returns a HTTP/1.1, 400 status response. *)
  end

  type handler = Request.t -> Response.t
  type middleware = handler -> handler

  (** {1 Run Server} *)

  val run :
    ?socket_backlog:int ->
    ?domains:int ->
    port:int ->
    Eio.Stdenv.t ->
    Eio.Switch.t ->
    handler ->
    unit

  (** {1 Basic Handlers} *)

  val not_found : handler
end
