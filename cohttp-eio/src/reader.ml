(* Based on https://github.com/inhabitedtype/angstrom/blob/master/lib/buffering.ml *)
type t = {
  mutable buf : Cstruct.t;
  mutable off : int;
  mutable len : int;
  source : Eio.Flow.source;
  buffer_size : int;
}

let default_io_buffer_size = 4096

let create ?(buffer_size = default_io_buffer_size) source =
  assert (buffer_size > 0);
  let buf = Cstruct.create buffer_size in
  let off = 0 in
  let len = 0 in
  { buf; off; len; source; buffer_size }

let buffer_size t = t.buffer_size
let unconsumed_len t = t.len - t.off
let buffer t = Cstruct.sub t.buf t.off t.len

let grow t size =
  let new_len = size + unconsumed_len t in
  let new_buf = Cstruct.create new_len in
  Cstruct.blit t.buf t.off new_buf 0 t.len;
  t.buf <- new_buf;
  t.off <- 0

let consume t n =
  assert (t.len >= n);
  t.off <- t.off + n;
  t.len <- t.len - n;
  Cstruct.blit t.buf t.off t.buf 0 t.len;
  t.off <- 0

let fill ?(len = default_io_buffer_size) t =
  grow t len;
  let write_off = t.off + t.len in
  let buf = Cstruct.sub t.buf write_off len in
  let got = Eio.Flow.read t.source buf in
  t.len <- t.len + got

exception Parse_error of string

let rec parse_request t =
  let open Http.Private in
  let buf = buffer t |> Cstruct.to_string in
  match Parser.parse_request buf with
  | Ok (req, len) ->
      consume t len;
      req
  | Error Parser.Partial ->
      fill t;
      parse_request t
  | Error (Msg msg) -> raise (Parse_error msg)

let rec parse_chunk_length t =
  let open Http.Private in
  let buf = buffer t |> Cstruct.to_string in
  match Parser.parse_chunk_length buf with
  | Ok (chunk_len, len) ->
      consume t len;
      chunk_len
  | Error Parser.Partial ->
      fill t;
      parse_chunk_length t
  | Error (Msg msg) -> raise (Parse_error msg)
