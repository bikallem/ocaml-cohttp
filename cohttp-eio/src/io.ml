type 'a t = 'a
type ic = In_channel.t
type oc = Eio.Flow.write
type conn = Eio.Flow.two_way
type error = exn

let ( >>= ) = ( |> )
let return a = a
let read_line (ic : ic) : string option t = In_channel.read_line ic
let read (ic : ic) len = In_channel.read ic len
let write oc s : unit t = Eio.Flow.copy_string s oc
let flush (_ : oc) : unit t = ()
let catch f = try Ok (f ()) with exn -> Error exn
let pp_error = Fmt.exn
