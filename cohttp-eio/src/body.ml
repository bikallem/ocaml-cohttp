type t = [ `String of Cstruct.t | `Chunked of unit -> chunk ]

and chunk =
  | Chunk of { data : Cstruct.t; extensions : chunk_extension list }
  | Last_chunk of Http.Request.t

and chunk_extension = { name : string; value : string option }
