(** [Body] is HTTP request or response body. *)

(** [reader] reads HTTP request or response body. *)
class virtual ['a] reader :
  object
    method virtual read : 'a option
  end

(** [writer] reads HTTP request or response body. *)
class virtual writer :
  object
    method virtual write : Eio.Buf_write.t -> unit
    method virtual headers : (string * string) list
  end

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

val fixed_writer : string -> writer
(** [fixed_writer s] is a {!class:writer} which writes [s] as a body and adds
    HTTP header [Content-Length] to HTTP request or response. *)

val fixed_reader : Http.Header.t -> Eio.Buf_read.t -> string reader
(** [fixed_reader header buf_read] is a {!class:reader} which reads bytes
    [Some b] using [buf_read] from a request/response if [Content-Length] exists
    in [header]. Otherwise the read result of this reader is [None]. *)

val form_values_writer : (string * string) list -> writer
(** [form_values_writer key_values] is a {!class:writer} which writes an
    associated list [key_values] as body and adds HTTP header [Content-Length]
    to HTTP request or response. *)

(** [Chunked] implementes HTTP [chunked] Transfer-Encoding encoder and decoders. *)
module Chunked : sig
  (** [t] is [chunked] body which can either be:

      - {!val:Chunk} represents a chunk body which contains data
      - {!val:Last_chunk} represents the last item in chunked transfer encoding
        signalling the end of transmission. *)
  type t = Chunk of body | Last_chunk of extension list

  and body = { size : int; data : string; extensions : extension list }
  and extension = { name : string; value : string option }

  (** {1 Encoder - Writer} *)

  type write_chunk = (t -> unit) -> unit
  type write_trailer = (Http.Header.t -> unit) -> unit

  val writer : ?write_trailers:bool -> write_chunk -> write_trailer -> writer
  (** [writer write_chunk write_trailer] is the HTTP [chunked] transfer encoder. *)

  (** {1 Decoder - Reader} *)

  val reader :
    Eio.Buf_read.t -> Http.Header.t -> (t -> unit) -> Http.Header.t reader
  (** [reader buf_write header chunk_reader] is the HTPP [chunked] transfer
      decoder. *)

  (** {1 Pretty Printers} *)

  val pp : Format.formatter -> t -> unit
  val pp_extension : Format.formatter -> extension list -> unit
end

val write : #writer -> Eio.Buf_write.t -> unit
(** [write writer buf_write] runs [writer] to [buf_write]. *)

val headers : #writer -> (string * string) list
(** [header writer] is [Some(header_name, header_value)] to denote the HTTP
    header the [writer] will write to request/response. It is [None] otherwise. *)

val read : 'a #reader -> 'a option
(** [read reader] is [Some x] if [reader] is successfully able to read from
    request/response body. It is [None] otherwise. *)
