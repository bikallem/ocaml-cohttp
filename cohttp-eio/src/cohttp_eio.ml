(** Buffered Input_channel.

    Inspired by https://github.com/ocaml/RFCs/blob/master/rfcs/modular_io.md *)
module In_channel = struct
  type t = { fill_buf : unit -> Cstruct.t * int * int; consume : int -> unit }

  let io_buffer_size = 4096

  let of_flow ?(bufsize = io_buffer_size) flow =
    let buf = Cstruct.create bufsize in
    let pos = ref 0 in
    let len = ref 0 in
    let consume n = pos := !pos + n in
    let fill_buf () =
      if !pos >= !len then (
        pos := 0;
        match Eio.Flow.read_into flow buf with
        | got -> len := got
        | exception End_of_file -> len := 0);
      (buf, !pos, !len - !pos)
    in
    { fill_buf; consume }

  let[@inline] fill_buf t = t.fill_buf ()
  let[@inline] consume t n = t.consume n
end

module Cstruct = struct
  include Cstruct

  let index_from t c ~pos ~len : int =
    assert (len <= Cstruct.length t);
    let rec index_aux i =
      if i >= len then raise Not_found
      else if Cstruct.get_char t i = c then i
      else (index_aux [@tailcall]) (i + 1)
    in
    index_aux pos
end

module IO = struct
  type 'a t = 'a
  type ic = In_channel.t
  type oc = Eio.Flow.write
  type conn = Eio.Flow.two_way
  type error = exn

  let ( >>= ) = ( |> )
  let return a = a

  let read_line (ic : ic) : string option t =
    let nl = '\n' in
    let buf = Buffer.create 256 in
    let rec read_until_nl (cs, pos, len) =
      if len = 0 then ()
      else
        match Cstruct.index_from cs nl ~pos ~len with
        | j ->
            let str = Cstruct.(sub cs pos (j - pos) |> to_string) in
            In_channel.consume ic (j - pos + 1);
            Buffer.add_string buf str
        | exception Not_found ->
            Buffer.add_string buf (Cstruct.to_string cs);
            In_channel.consume ic len;
            (read_until_nl [@tailcall]) (In_channel.fill_buf ic)
    in
    read_until_nl (In_channel.fill_buf ic);
    let len = Buffer.length buf in
    if len = 0 then None
    else
      let line = Buffer.contents buf in
      if line.[len - 1] = '\r' then
        let line = String.sub line 0 (len - 1) in
        if String.length line > 0 then Some line else None
      else Some line

  let read (ic : ic) len : string t =
    let buf = Buffer.create 0 in
    let rec read_until total (cs, pos, len') =
      match len' with
      | 0 -> ()
      | _ ->
          let total = total + len' in
          if total >= len then
            let text = Cstruct.sub cs pos (total - len) |> Cstruct.to_string in
            Buffer.add_string buf text
          else (
            Buffer.add_string buf (Cstruct.to_string cs);
            In_channel.consume ic len';
            (read_until [@tailcall]) total (In_channel.fill_buf ic))
    in
    read_until 0 (In_channel.fill_buf ic);
    Buffer.contents buf

  let write oc s : unit t = Eio.Flow.copy_string s oc
  let flush (_ : oc) : unit t = ()
  let catch f = try Ok (f ()) with exn -> Error exn
  let pp_error = Fmt.exn
end
