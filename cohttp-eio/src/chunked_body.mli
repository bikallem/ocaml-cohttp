(** [Chunked] implementes HTTP [chunked] Transfer-Encoding encoder and decoders. *)

(** [t] is [chunked] body which can either be:

    - {!val:Chunk} represents a chunk body which contains data
    - {!val:Last_chunk} represents the last item in chunked transfer encoding
      signalling the end of transmission. *)
type t = Chunk of body | Last_chunk of extension list

and body = { size : int; data : string; extensions : extension list }
and extension = { name : string; value : string option }

(** {1 Writer} *)

type write_chunk = (t -> unit) -> unit
type write_trailer = (Http.Header.t -> unit) -> unit

val writer :
  ua_supports_trailer:bool -> write_chunk -> write_trailer -> Body.writer
(** [writer ~ua_supports_trailer write_chunk write_trailer] is the HTTP
    [chunked] transfer encoder. *)

(** {1 Reader} *)

val reader : Http.Header.t -> (t -> unit) -> Http.Header.t Body.reader
(** [reader header chunk_reader] is the HTPP [chunked] transfer decoder. *)

val read_chunked : #Body.buffered_reader -> (t -> unit) -> Http.Header.t option
(** [read_chunked reader chunk_handler] is [Some updated_headers] if
    "Transfer-Encoding" header value is "chunked" in [request] and all chunks in
    [buf_read] are read successfully. [updated_headers] is the updated headers
    as specified by the chunked encoding algorithm in https:
    //datatracker.ietf.org/doc/html/rfc7230#section-4.1.3.

    Returns [None] if [Transfer-Encoding] header in [headers] is not specified
    as "chunked" *)

(** {1 Pretty Printers} *)

val pp : Format.formatter -> t -> unit
val pp_extension : Format.formatter -> extension list -> unit
