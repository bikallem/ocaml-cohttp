open Angstrom

let token =
  take_while1 (function
    | '0' .. '9'
    | 'a' .. 'z'
    | 'A' .. 'Z'
    | '!' | '#' | '$' | '%' | '&' | '\'' | '*' | '+' | '-' | '.' | '^' | '_'
    | '`' | '|' | '~' ->
        true
    | _ -> false)

let space = char '\x20'
let htab = char '\t'
let ows = skip_many (space <|> htab)
let optional x = option None (x >>| Option.some)
let vchar = satisfy (function '\x21' .. '\x7E' -> true | _ -> false)
let digit = satisfy (function '0' .. '9' -> true | _ -> false)
let crlf = string_ci "\r\n" <?> "[crlf]"

(*-- https://datatracker.ietf.org/doc/html/rfc7230#section-3.2 --*)
let request_headers =
  let header_field =
    let* header_name = token <* char ':' <* ows >>| String.lowercase_ascii in
    let+ header_value =
      let field_content =
        let c2 =
          optional
            (let+ c1 = skip_many1 (space <|> htab) *> vchar in
             Format.sprintf " %c" c1)
          >>| function
          | Some s -> s
          | None -> ""
        in
        lift2 (fun c1 c2 -> Format.sprintf "%c%s" c1 c2) vchar c2
      in
      many field_content >>| String.concat "" <* crlf <* commit
    in
    (header_name, header_value)
  in
  many header_field <* commit >>| Http.Header.of_list_rev

(*-- request-line = method SP request-target SP HTTP-version CRLF HTTP headers *)
let[@warning "-3"] request =
  let* meth = token >>| Http.Method.of_string <* space in
  let* resource = take_while1 (fun c -> c != ' ') <* space in
  let* version =
    let* v = string "HTTP/1." *> digit <* crlf in
    match v with
    | '1' -> return `HTTP_1_1
    | '0' -> return `HTTP_1_0
    | _ -> fail (Format.sprintf "Invalid HTTP version: %c" v)
  in
  let+ headers = request_headers <* commit in
  {
    Http.Request.headers;
    meth;
    scheme = None;
    resource;
    version;
    encoding = Http.Header.get_transfer_encoding headers;
  }


let io_buffer_size = 65536 (* UNIX_BUFFER_SIZE 4.0.0 in bytes *)

let parse :
    'a Angstrom.t ->
    #Eio.Flow.read ->
    Cstruct.t ->
    [ `Done of Cstruct.t * 'a | `Error of string ] =
 fun p client_fd unconsumed ->
  let rec loop = function
    | Buffered.Partial k -> (
        let unconsumed_length = Cstruct.length unconsumed in
        if unconsumed_length > 0 then
          loop @@ k (`Bigstring (Cstruct.to_bigarray unconsumed))
        else
          let buf = Cstruct.create io_buffer_size in
          match Eio.Flow.read_into client_fd buf with
          | got ->
              let buf =
                (if got != io_buffer_size then Cstruct.sub buf 0 got else buf)
                |> Cstruct.to_bigarray
              in
              loop (k (`Bigstring buf))
          | exception End_of_file -> loop (k `Eof))
    | Buffered.Done ({ off; len; buf }, x) ->
        let unconsumed =
          if len > 0 then Cstruct.of_bigarray ~off ~len buf else Cstruct.empty
        in
        `Done (unconsumed, x)
    | Buffered.Fail (_, marks, err) ->
        `Error (String.concat " > " marks ^ ": " ^ err)
  in
  loop (Buffered.parse p)
