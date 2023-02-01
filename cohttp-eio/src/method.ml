type none = Body2.none

type 'a t =
  | Get : none t
  | Head : none t
  | Delete : none t
  | Options : none t
  | Trace : none t
  | Post : #Body2.writer t
  | Put : #Body2.writer t
  | Patch : #Body2.writer t
  | Connect : none t

let to_string (type a) (_m : a t) = failwith "not implemented"
