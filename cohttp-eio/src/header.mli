include module type of Http.Header with type t = Http.Header.t

val fmt : t -> Easy_format.t
val pp : Format.formatter -> t -> unit
