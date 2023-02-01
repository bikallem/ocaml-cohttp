class virtual ['a] reader :
  object
    method virtual read : 'a option
  end

class virtual writer :
  object
    method virtual write : Eio.Buf_write.t -> unit
    method virtual header : (string * string) option
  end

type empty

class virtual none :
  object
    inherit writer
    inherit [empty] reader
  end

val none : none
val fixed_writer : string -> writer
val fixed_reader : Http.Header.t -> Eio.Buf_read.t -> string reader

module Chunked : sig
  type t = Chunk of body | Last_chunk of extension list
  and body = { size : int; data : string; extensions : extension list }
  and extension = { name : string; value : string option }

  val pp : Format.formatter -> t -> unit
  val pp_extension : Format.formatter -> extension list -> unit

  type write_chunk = (t -> unit) -> unit
  type write_trailer = (Http.Header.t -> unit) -> unit

  val writer : ?write_trailers:bool -> write_chunk -> write_trailer -> writer

  val reader :
    Eio.Buf_read.t -> Http.Header.t -> (t -> unit) -> Http.Header.t reader
end

val write : #writer -> Eio.Buf_write.t -> unit
val header : #writer -> (string * string) option
val read : 'a #reader -> 'a option
