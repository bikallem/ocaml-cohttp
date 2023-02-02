module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

class virtual ['a] reader =
  object
    method virtual read : 'a option
  end

class virtual writer =
  object
    method virtual write : Eio.Buf_write.t -> unit
    method virtual headers : (string * string) list
  end

type void = |

class none =
  object
    inherit writer
    inherit [void] reader
    method read = None
    method write _ = ()
    method headers = []
  end

let none = new none

class fixed_writer body =
  object
    inherit writer
    method write writer = Buf_write.string writer body
    method headers = [ ("Content-Length", string_of_int @@ String.length body) ]
  end

let fixed_writer body = new fixed_writer body

let fixed_reader headers r =
  object
    inherit [string] reader

    method read =
      Option.map
        (fun len -> Buf_read.take (int_of_string len) r)
        (Http.Header.get headers "Content-Length")
  end

module Chunked = struct
  type t = Chunk of body | Last_chunk of extension list
  and body = { size : int; data : string; extensions : extension list }
  and extension = { name : string; value : string option }

  let pp_extension fmt =
    Fmt.(
      vbox
      @@ list ~sep:Fmt.semi
      @@ record
           [
             Fmt.field "name" (fun ext -> ext.name) Fmt.string;
             Fmt.field "value" (fun ext -> ext.value) Fmt.(option string);
           ])
      fmt

  let pp fmt = function
    | Chunk chunk ->
        Fmt.(
          record
            [
              Fmt.field "size" (fun _t -> chunk.size) Fmt.int;
              Fmt.field "data" (fun _t -> chunk.data) Fmt.string;
              Fmt.field "extensions" (fun t -> t.extensions) pp_extension;
            ])
          fmt chunk
    | Last_chunk extensions -> pp_extension fmt extensions

  (* Chunked encoding parser *)

  let hex_digit = function
    | '0' .. '9' -> true
    | 'a' .. 'f' -> true
    | 'A' .. 'F' -> true
    | _ -> false

  let quoted_char =
    let open Buf_read.Syntax in
    let+ c = Buf_read.any_char in
    match c with
    | ' ' | '\t' | '\x21' .. '\x7E' -> c
    | c -> failwith (Printf.sprintf "Invalid escape \\%C" c)

  (*-- qdtext = HTAB / SP /%x21 / %x23-5B / %x5D-7E / obs-text -- *)
  let qdtext = function
    | ('\t' | ' ' | '\x21' | '\x23' .. '\x5B' | '\x5D' .. '\x7E') as c -> c
    | c -> failwith (Printf.sprintf "Invalid quoted character %C" c)

  (*-- quoted-string = DQUOTE *( qdtext / quoted-pair ) DQUOTE --*)
  let quoted_string r =
    Buf_read.char '"' r;
    let buf = Buffer.create 100 in
    let rec aux () =
      match Buf_read.any_char r with
      | '"' -> Buffer.contents buf
      | '\\' ->
          Buffer.add_char buf (quoted_char r);
          aux ()
      | c ->
          Buffer.add_char buf (qdtext c);
          aux ()
    in
    aux ()

  let optional c x r =
    let c2 = Buf_read.peek_char r in
    if Some c = c2 then (
      Buf_read.consume r 1;
      Some (x r))
    else None

  (*-- https://datatracker.ietf.org/doc/html/rfc7230#section-4.1 --*)
  let chunk_ext_val =
    let open Buf_read.Syntax in
    let* c = Buf_read.peek_char in
    match c with Some '"' -> quoted_string | _ -> Rwer.token

  let rec chunk_exts r =
    let c = Buf_read.peek_char r in
    match c with
    | Some ';' ->
        Buf_read.consume r 1;
        let name = Rwer.token r in
        let value = optional '=' chunk_ext_val r in
        { name; value } :: chunk_exts r
    | _ -> []

  let chunk_size =
    let open Buf_read.Syntax in
    let* sz = Rwer.take_while1 hex_digit in
    try Buf_read.return (Format.sprintf "0x%s" sz |> int_of_string)
    with _ -> failwith (Format.sprintf "Invalid chunk_size: %s" sz)

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
    | "age" | "expires" | "date" | "location" | "retry-after" | "vary"
    | "warning"
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
    let open Buf_read.Syntax in
    let* sz = chunk_size in
    match sz with
    | sz when sz > 0 ->
        let* extensions = chunk_exts <* Rwer.crlf in
        let* data = Buf_read.take sz <* Rwer.crlf in
        Buf_read.return @@ `Chunk (sz, data, extensions)
    | 0 ->
        let* extensions = chunk_exts <* Rwer.crlf in
        (* Read trailer headers if any and append those to request headers.
           Only headers names appearing in 'Trailer' request headers and "allowed" trailer
           headers are appended to request.
           The spec at https://datatracker.ietf.org/doc/html/rfc7230#section-4.1.3
           specifies that 'Content-Length' and 'Transfer-Encoding' headers must be
           updated. *)
        let* trailer_headers = Rwer.http_headers in
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
        Buf_read.return @@ `Last_chunk (extensions, headers)
    | sz -> failwith (Format.sprintf "Invalid chunk size: %d" sz)

  type write_chunk = (t -> unit) -> unit
  type write_trailer = (Http.Header.t -> unit) -> unit

  let writer ?(write_trailers = false) write_chunk write_trailer : writer =
    object
      inherit writer
      method headers = [ ("Transfer-Encoding", "chunked") ]

      method write writer =
        let write_extensions exts =
          List.iter
            (fun { name; value } ->
              let v =
                match value with None -> "" | Some v -> Printf.sprintf "=%s" v
              in
              Buf_write.string writer (Printf.sprintf ";%s%s" name v))
            exts
        in
        let write_body = function
          | Chunk { size; data; extensions = exts } ->
              Buf_write.string writer (Printf.sprintf "%X" size);
              write_extensions exts;
              Buf_write.string writer "\r\n";
              Buf_write.string writer data;
              Buf_write.string writer "\r\n"
          | Last_chunk exts ->
              Buf_write.string writer "0";
              write_extensions exts;
              Buf_write.string writer "\r\n"
        in
        write_chunk write_body;
        if write_trailers then write_trailer (Rwer.write_headers writer);
        Buf_write.string writer "\r\n"
    end

  let reader buf_read headers f : Http.Header.t reader =
    object
      inherit [Http.Header.t] reader

      method read =
        match Http.Header.get_transfer_encoding headers with
        | Http.Transfer.Chunked ->
            let total_read = ref 0 in
            let rec chunk_loop f =
              let chunk = chunk !total_read headers buf_read in
              match chunk with
              | `Chunk (size, data, extensions) ->
                  f (Chunk { size; data; extensions });
                  total_read := !total_read + size;
                  (chunk_loop [@tailcall]) f
              | `Last_chunk (extensions, headers) ->
                  f (Last_chunk extensions);
                  Some headers
            in
            chunk_loop f
        | _ -> None
    end
end

let write (w : #writer) = w#write
let headers (w : #writer) = w#headers
let read (r : _ #reader) = r#read
