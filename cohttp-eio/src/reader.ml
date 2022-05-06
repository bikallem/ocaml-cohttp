(* Based on https://github.com/inhabitedtype/angstrom/blob/master/lib/buffering.ml *)
type t = {
  source : Eio.Flow.source;
  mutable buf : Bigstringaf.t;
  mutable off : int;
  mutable len : int;
  mutable pos : int; (* Parser position *)
  mutable committed_bytes : int; (* Total bytes read so far *)
}

let create len source =
  assert (len > 0);
  let buf = Bigstringaf.create len in
  { source; buf; off = 0; len = 0; pos = 0; committed_bytes = 0 }

let length t = t.len
let committed_bytes t = t.committed_bytes
let pos t = t.pos
let incr_pos ?(n = 1) t = t.pos <- t.pos + n
let writable_space t = Bigstringaf.length t.buf - t.len
let trailing_space t = Bigstringaf.length t.buf - (t.off + t.len)

let compress t =
  Bigstringaf.unsafe_blit t.buf ~src_off:t.off t.buf ~dst_off:0 ~len:t.len;
  t.off <- 0

let grow t to_copy =
  let old_len = Bigstringaf.length t.buf in
  let new_len = ref old_len in
  let space = writable_space t in
  while space + !new_len - old_len < to_copy do
    new_len := 3 * (!new_len + 1) / 2
  done;
  let new_buf = Bigstringaf.create !new_len in
  Bigstringaf.unsafe_blit t.buf ~src_off:t.off new_buf ~dst_off:0 ~len:t.len;
  t.buf <- new_buf;
  t.off <- 0

let adjust_buffer t to_read =
  if trailing_space t < to_read then
    if writable_space t < to_read then grow t to_read else compress t

let consume t n =
  assert (t.len >= n);
  assert (t.pos >= n);
  t.off <- t.off + n;
  t.len <- t.len - n;
  t.pos <- t.pos - n;
  t.committed_bytes <- t.committed_bytes + n

let commit t = consume t t.pos

let fill t to_read =
  adjust_buffer t to_read;
  let off = t.off + t.len in
  let len = trailing_space t in
  let cs = Cstruct.of_bigarray ~off ~len t.buf in
  let got = Eio.Flow.read t.source cs in
  t.len <- t.len + got;
  got

let unsafe_get t off = Bigstringaf.unsafe_get t.buf (t.off + off)

let substring t ~off ~len =
  let b = Bytes.create len in
  Bigstringaf.unsafe_blit_to_bytes t.buf ~src_off:(t.off + off) b ~dst_off:0
    ~len;
  Bytes.unsafe_to_string b

let copy t ~off ~len = Bigstringaf.copy t.buf ~off:(t.off + off) ~len

(** Parser combinators *)

type 'a parser = t -> 'a

exception Parse_failure of string

let return v _ = v
let fail err _ = Stdlib.raise_notrace (Parse_failure err)
let commit rdr = commit rdr
let ( <?> ) p err rdr = try p rdr with Parse_failure _e -> fail err rdr

let ( >>= ) p f rdr =
  let a = p rdr in
  f a rdr

let ( let* ) = ( >>= )

let ( >>| ) p f rdr =
  let v = p rdr in
  f v

let ( let+ ) = ( >>| )

let ( <* ) p q rdr =
  let a = p rdr in
  let _ = q rdr in
  a

let ( *> ) p q rdr =
  let _ = p rdr in
  q rdr

let ( <|> ) p q rdr =
  let old_pos = pos rdr in
  let old_committed = committed_bytes rdr in
  try p rdr
  with Parse_failure _ as ex ->
    if old_committed < committed_bytes rdr then raise_notrace ex
    else (
      rdr.pos <- old_pos;
      q rdr)

let lift f p = p >>| f

let lift2 f p q rdr =
  let a = p rdr in
  let b = q rdr in
  f a b

let rec ensure rdr len =
  if length rdr < pos rdr + len then (
    ignore (fill rdr len);
    ensure rdr len)

(* let pos rdr = pos rdr *)

let end_of_input rdr =
  try
    ensure rdr 1;
    false
  with End_of_file -> true

let option : 'a -> 'a parser -> 'a parser = fun x p -> p <|> return x

let peek_char rdr =
  if pos rdr < length rdr then unsafe_get rdr (pos rdr)
  else (
    ensure rdr 1;
    unsafe_get rdr rdr.pos)

let peek_string n rdr =
  try
    ensure rdr n;
    substring rdr ~off:rdr.pos ~len:n
  with End_of_file -> fail "[peek_string] not enough input" rdr

let sprintf = Printf.sprintf

let char c rdr =
  let c' = peek_char rdr in
  if c = c' then incr_pos rdr
  else fail (sprintf "[char] expected %C, got %C" c c') rdr

let any_char rdr =
  ensure rdr 1;
  let c = unsafe_get rdr rdr.pos in
  incr_pos rdr;
  c

let satisfy f rdr =
  let c = peek_char rdr in
  if f c then (
    incr_pos rdr;
    c)
  else fail "[satisfy]" rdr

let string s rdr =
  let len = String.length s in
  ensure rdr len;
  let pos = pos rdr in
  let i = ref 0 in
  while
    !i < len && Char.equal (unsafe_get rdr (pos + !i)) (String.unsafe_get s !i)
  do
    incr i
  done;
  if len = !i then incr_pos ~n:len rdr else fail "[string]" rdr

let fix f =
  let rec p = lazy (f r) and r inp = (Lazy.force p) inp in
  r

let count_while rdr f =
  let i = ref 0 in
  let continue = ref true in
  while !continue do
    try
      ensure rdr (!i + 1);
      let c = unsafe_get rdr (pos rdr + !i) in
      if f c then incr i else continue := false
    with End_of_file -> continue := false
  done;
  !i

let take_while1 f rdr =
  let count = count_while rdr f in
  if count < 1 then fail "[take_while1] count is less than 1" rdr
  else
    let s = substring rdr ~off:(pos rdr) ~len:count in
    incr_pos ~n:count rdr;
    s

let take_while f rdr =
  let count = count_while rdr f in
  if count > 0 then (
    let s = substring rdr ~off:(pos rdr) ~len:count in
    incr_pos ~n:count rdr;
    s)
  else ""

let take_bigstring : int -> Bigstringaf.t parser =
 fun n rdr ->
  try
    ensure rdr n;
    let s = copy rdr ~off:(pos rdr) ~len:n in
    incr_pos ~n rdr;
    s
  with End_of_file -> fail "[take_bigstring] not enough input" rdr

let take : int -> string parser =
 fun n rdr ->
  try
    ensure rdr n;
    let s = substring rdr ~off:(pos rdr) ~len:n in
    incr_pos ~n rdr;
    s
  with End_of_file -> fail "[take] not enough input" rdr

let take_till f = take_while (fun c -> not (f c))

let rec many : 'a parser -> 'a list parser =
 fun p rdr ->
  try
    let a = p rdr in
    a :: many p rdr
  with Parse_failure _ | End_of_file -> []

let rec many_till : 'a parser -> _ parser -> 'a list parser =
 fun p t rdr ->
  try
    let _ = t rdr in
    let a = p rdr in
    a :: many_till p t rdr
  with Parse_failure _ -> []

let skip f rdr =
  ensure rdr 1;
  let c = unsafe_get rdr (pos rdr) in
  if f c then incr_pos rdr else fail "[skip]" rdr

let skip_while f rdr =
  let count = count_while rdr f in
  incr_pos ~n:count rdr

let rec skip_many p rdr =
  match p rdr with _ -> skip_many p rdr | exception Parse_failure _ -> ()

(* Builtin readers *)

let token =
  take_while1 (function
    | '0' .. '9'
    | 'a' .. 'z'
    | 'A' .. 'Z'
    | '!' | '#' | '$' | '%' | '&' | '\'' | '*' | '+' | '-' | '.' | '^' | '_'
    | '`' | '|' | '~' ->
        true
    | _ -> false)

let ows = skip_while (function ' ' | '\t' -> true | _ -> false)
let crlf = string "\r\n"
let is_cr = function '\r' -> true | _ -> false
let space = char '\x20'
let p_meth = token <* space >>| Http.Method.of_string
let p_resource = take_while1 (fun c -> c != ' ') <* space

let p_version =
  string "HTTP/1." *> any_char <* crlf >>= function
  | '1' -> return `HTTP_1_1
  | '0' -> return `HTTP_1_0
  | v -> fail (Format.sprintf "Invalid HTTP version: %C" v)

let header =
  lift2
    (fun key value -> (key, value))
    (token <* char ':' <* ows)
    (take_till is_cr <* crlf)

let headers' =
  let cons x xs = x :: xs in
  fix (fun headers ->
      let _emp = return [] in
      let _rec = lift2 cons header headers in
      peek_char >>= function '\r' -> _emp | _ -> _rec)
  >>| Http.Header.of_list
  <* crlf

let[@warning "-3"] request t =
  match end_of_input t with
  | true -> Stdlib.raise_notrace End_of_file
  | false ->
      let meth = p_meth t in
      let resource = p_resource t in
      let version = p_version t in
      let headers = headers' t in
      let encoding = Http.Header.get_transfer_encoding headers in
      commit t;
      { Http.Request.meth; resource; version; headers; scheme = None; encoding }

let read_fixed =
  let read_complete = ref false in
  fun t headers ->
    if !read_complete then Error "End of file"
    else
      match Http.Header.get headers "content-length" with
      | Some v -> (
          try
            let content_length = int_of_string v in
            let content = take content_length t in
            read_complete := true;
            Ok content
          with e -> Error (Printexc.to_string e))
      | None -> Error "Request is not a fixed content body"

(* Chunked encoding parser *)

let hex_digit = function
  | '0' .. '9' -> true
  | 'a' .. 'f' -> true
  | 'A' .. 'F' -> true
  | _ -> false

let quoted_pair =
  char '\\'
  *> satisfy (function ' ' | '\t' | '\x21' .. '\x7E' -> true | _ -> false)

(*-- qdtext = HTAB / SP /%x21 / %x23-5B / %x5D-7E / obs-text -- *)
let qdtext =
  satisfy (function
    | '\t' | ' ' | '\x21' | '\x23' .. '\x5B' -> true
    | '\x5D' .. '\x7E' -> true
    | _ -> false)

(*-- quoted-string = DQUOTE *( qdtext / quoted-pair ) DQUOTE --*)
let quoted_string =
  let dquote = char '"' in
  let+ chars = dquote *> many_till (qdtext <|> quoted_pair) dquote <* dquote in
  String.of_seq @@ List.to_seq chars

let optional x = option None (x >>| Option.some)

(*-- https://datatracker.ietf.org/doc/html/rfc7230#section-4.1 --*)
let chunk_exts =
  let chunk_ext_name = token in
  let chunk_ext_val = quoted_string <|> token in
  many
    (lift2
       (fun name value : Chunk.extension -> { name; value })
       (char ';' *> chunk_ext_name)
       (optional (char '=' *> chunk_ext_val)))

let chunk_size =
  let* sz = take_while1 hex_digit in
  try return (Format.sprintf "0x%s" sz |> int_of_string)
  with _ -> fail (Format.sprintf "Invalid chunk_size: %s" sz)

(* Be strict about headers allowed in trailer headers to minimize security
   issues, eg. request smuggling attack -
   https://portswigger.net/web-security/request-smuggling
   Allowed headers are defined in 2nd paragraph of
   https://datatracker.ietf.org/doc/html/rfc7230#section-4.1.2 *)
let is_trailer_header_allowed h =
  match String.lowercase_ascii h with
  | "transfer-encoding" | "content-length" | "host"
  (* Request control headers are not allowed. *)
  | "cache-control" | "expect" | "max-forwards" | "pragma" | "range" | "te"
  (* Authentication headers are not allowed. *)
  | "www-authenticate" | "authorization" | "proxy-authenticate"
  | "proxy-authorization"
  (* Cookie headers are not allowed. *)
  | "cookie" | "set-cookie"
  (* Response control data headers are not allowed. *)
  | "age" | "expires" | "date" | "location" | "retry-after" | "vary" | "warning"
  (* Headers to process the payload are not allowed. *)
  | "content-encoding" | "content-type" | "content-range" | "trailer" ->
      false
  | _ -> true

(* Request indiates which headers will be sent in chunk trailer part by
   specifying the headers in comma separated value in 'Trailer' header. *)
let request_trailer_headers headers =
  match Http.Header.get headers "Trailer" with
  | Some v -> List.map String.trim @@ String.split_on_char ',' v
  | None -> []

(* Chunk decoding algorithm is explained at
   https://datatracker.ietf.org/doc/html/rfc7230#section-4.1.3 *)
let chunk (total_read : int) (headers : Http.Header.t) =
  let* sz = chunk_size in
  match sz with
  | sz when sz > 0 ->
      let* extensions = chunk_exts <* crlf in
      let* data = take_bigstring sz <* crlf >>| Cstruct.of_bigarray in
      return @@ `Chunk (sz, data, extensions)
  | 0 ->
      let* extensions = chunk_exts <* crlf in
      (* Read trailer headers if any and append those to request headers.
         Only headers names appearing in 'Trailer' request headers and "allowed" trailer
         headers are appended to request.
         The spec at https://datatracker.ietf.org/doc/html/rfc7230#section-4.1.3
         specifies that 'Content-Length' and 'Transfer-Encoding' headers must be
         updated. *)
      let* trailer_headers = headers' <* commit in
      let request_trailer_headers = request_trailer_headers headers in
      let trailer_headers =
        List.filter
          (fun (name, _) ->
            List.mem name request_trailer_headers
            && is_trailer_header_allowed name)
          (Http.Header.to_list trailer_headers)
      in
      let request_headers =
        List.fold_left
          (fun h (key, v) -> Http.Header.add h key v)
          headers trailer_headers
      in
      (* Remove either just the 'chunked' from Transfer-Encoding header value or
         remove the header entirely if value is empty. *)
      let te_header = "Transfer-Encoding" in
      let request_headers =
        match Http.Header.get request_headers te_header with
        | Some header_value ->
            let new_header_value =
              String.split_on_char ',' header_value
              |> List.map String.trim
              |> List.filter (fun v ->
                     let v = String.lowercase_ascii v in
                     not (String.equal v "chunked"))
              |> String.concat ","
            in
            if String.length new_header_value > 0 then
              Http.Header.replace request_headers te_header new_header_value
            else Http.Header.remove request_headers te_header
        | None -> assert false
      in
      (* Remove 'Trailer' from request headers. *)
      let headers = Http.Header.remove request_headers "Trailer" in
      (* Add Content-Length header *)
      let headers =
        Http.Header.add headers "Content-Length" (string_of_int total_read)
      in
      return @@ `Last_chunk (extensions, headers)
  | sz -> fail (Format.sprintf "Invalid chunk size: %d" sz)

let read_chunked t headers =
  match Http.Header.get_transfer_encoding headers with
  | Http.Transfer.Chunked ->
      let total_read = ref 0 in
      let read_complete = ref false in
      let rec chunk_loop f =
        if !read_complete then Error "End of file"
        else
          let chunk = chunk !total_read headers t in
          match chunk with
          | `Chunk (size, data, extensions) ->
              f (Chunk.Chunk { size; data; extensions });
              total_read := !total_read + size;
              (chunk_loop [@tailcall]) f
          | `Last_chunk (extensions, headers) ->
              read_complete := true;
              f (Chunk.Last_chunk extensions);
              Ok headers
      in
      chunk_loop
  | _ -> fun _ -> Error "Request is not a chunked request"
