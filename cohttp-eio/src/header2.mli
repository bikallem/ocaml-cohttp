type name = private string
type lname = private string

val canonical_name : string -> name
val lname : string -> lname

type t
type 'a encode = 'a -> string
type 'a decode = string -> 'a

(** {1 Header} *)

type 'a header

val header : 'a decode -> 'a encode -> string -> 'a header
(** [header decoder encoder name] is {!type:header}. *)

val content_length : int header
val content_type : string header
val host : string header
val transfer_encoding : [ `compress | `deflate | `gzip | `chunked ] list header

(** {1 Create} *)

val empty : t
val is_empty : t -> bool
val of_list : (string * string) list -> t
val to_list : t -> (lname * string) list
val to_canonical_list : t -> (name * string) list

(** {1 Find} *)

val find : t -> 'a header -> 'a
val find_opt : t -> 'a header -> 'a option
val find_all : t -> 'a header -> 'a list
val exists : t -> 'a header -> bool

(** {1 Add} *)

val add : t -> 'a header -> 'a -> t
val add_unless_exists : t -> 'a header -> 'a -> t

(** {1 Update/Remove} *)

val remove : t -> 'a header -> t
val replace : t -> 'a header -> 'a -> t
