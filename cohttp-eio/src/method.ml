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
