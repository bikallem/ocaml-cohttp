type t = [ Cohttp.Body.t | `Stream of string Eio.Stream.t ] [@@deriving sexp_of]

val of_string : string -> t
val to_string : t -> string
val of_string_list : string list -> t
val to_string_list : t -> string list
val of_form : ?scheme:string -> (string * string list) list -> t
val to_form : t -> (string * string list) list
val of_stream : string Eio.Stream.t -> t
val to_stream : capacity:int -> t -> string Eio.Stream.t
val empty : t
val is_empty : t -> bool
val map : (string -> string) -> t -> t
val transfer_encoding : t -> Cohttp.Transfer.encoding
