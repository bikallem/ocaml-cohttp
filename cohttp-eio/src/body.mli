(** [Body] is HTTP request or response body. *)

type header = string * string
(** [header] is a HTTP header of [(name, value)] *)

(** {1 Writer} *)

(** [writer] reads HTTP request or response body. *)
class type writer =
  object
    method write_body : Eio.Buf_write.t -> unit
    method write_header : (name:string -> value:string -> unit) -> unit
  end

(** [content_writer s] is a {!class:writer} which writes [s] as a body and adds
    HTTP header [Content-Length] to HTTP request or response. *)
class content_writer :
  content:string
  -> content_type:string
  -> object
       inherit writer
     end

val content_writer : content:string -> content_type:string -> writer
(** [content_writer ~content ~content_type] is
    [new content_writer ~content ~content_type]. *)

val form_values_writer : (string * string) list -> writer
(** [form_values_writer key_values] is a {!class:writer} which writes an
    associated list [key_values] as body and adds HTTP header [Content-Length]
    to HTTP request or response. *)

(** {1 Reader} *)

(** [reader] reads HTTP request or response body. *)
class type ['a] reader =
  object
    method read : Eio.Buf_read.t -> 'a option
  end

(** [content_reader header] is a {!class:reader} which reads bytes [Some b] from
    request/response if [Content-Length] exists in [header]. Otherwise the read
    result of this reader is [None]. *)
class content_reader :
  Http.Header.t
  -> object
       inherit [string] reader
     end

val content_reader : Http.Header.t -> string reader
(** [content_reader headers] is [new content_reader headers] *)

(** {1 Chunked Reader/Writer} *)

(** [Chunked] implementes HTTP [chunked] Transfer-Encoding encoder and decoders. *)
module Chunked : sig
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
    ua_supports_trailer:bool -> write_chunk -> write_trailer -> writer
  (** [writer ~ua_supports_trailer write_chunk write_trailer] is the HTTP
      [chunked] transfer encoder. *)

  (** {1 Reader} *)

  val reader : Http.Header.t -> (t -> unit) -> Http.Header.t reader
  (** [reader header chunk_reader] is the HTPP [chunked] transfer decoder. *)

  (** {1 Pretty Printers} *)

  val pp : Format.formatter -> t -> unit
  val pp_extension : Format.formatter -> extension list -> unit
end

val read : 'a #reader -> Eio.Buf_read.t -> 'a option
(** [read reader] is [Some x] if [reader] is successfully able to read from
    request/response body. It is [None] otherwise. *)

val read_content :
  < headers : Http.Header.t ; buf_read : Eio.Buf_read.t ; .. > -> string option

val read_chunked :
  < headers : Http.Header.t ; buf_read : Eio.Buf_read.t ; .. > ->
  (Chunked.t -> unit) ->
  Http.Header.t option

(** {1 none} *)

type void
(** represents nothing - a noop. *)

(** [none] is a special type of reader and writer that represents the absence of
    HTTP request or response body - a {!type:void}. *)
class virtual none :
  object
    inherit writer
    inherit [void] reader
  end

val none : none
(** [none] is an instance of {!class:none}. *)
