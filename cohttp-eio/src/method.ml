type none = Body2.none

type 'a t =
  | Get : none t
  | Head : none t
  | Delete : none t
  | Options : none t
  | Trace : none t
  | Post : 'a t
  | Put : 'a t
  | Patch : 'a t
  | Connect : none t

let to_string (type a) (m : a t) =
  match m with
  | Get -> "GET"
  | Head -> "HEAD"
  | Delete -> "DELETE"
  | Options -> "OPTIONS"
  | Trace -> "TRACE"
  | Post -> "POST"
  | Put -> "PUT"
  | Patch -> "PATCH"
  | Connect -> "CONNECT"

let of_string (type a) s : a t =
  match String.uppercase_ascii s with
  | "GET" -> Obj.magic Get
  | "HEAD" -> Obj.magic Head
  | "DELETE" -> Obj.magic Delete
  | "OPTIONS" -> Obj.magic Options
  | "TRACE" -> Obj.magic Trace
  | "POST" -> Obj.magic Post
  | "PUT" -> Obj.magic Put
  | "PATCH" -> Obj.magic Patch
  | "CONNECT" -> Obj.magic Connect
  | _ -> raise @@ Invalid_argument ("Unsupported header: " ^ s)
