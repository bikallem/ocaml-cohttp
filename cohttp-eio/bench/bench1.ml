module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

module New_parser = struct
  let take_while1 p r =
    match Buf_read.take_while1 p r with
    | exception Failure _ -> raise End_of_file
    | x -> x

  let token =
    take_while1 (function
      | '0' .. '9'
      | 'a' .. 'z'
      | 'A' .. 'Z'
      | '!' | '#' | '$' | '%' | '&' | '\'' | '*' | '+' | '-' | '.' | '^' | '_'
      | '`' | '|' | '~' ->
          true
      | _ -> false)

  let ows = Buf_read.skip_while (function ' ' | '\t' -> true | _ -> false)
  let crlf = Buf_read.string "\r\n"
  let not_cr = function '\r' -> false | _ -> true

  let header =
    let open Eio.Buf_read.Syntax in
    let+ key = token <* Buf_read.char ':' <* ows
    and+ value = Buf_read.take_while not_cr <* crlf in
    (key, value)

  let http_headers : Buf_read.t -> Http.Header.t =
   fun r ->
    let[@tail_mod_cons] rec aux () =
      match Buf_read.peek_char r with
      | Some '\r' ->
          crlf r;
          []
      | _ ->
          let h = header r in
          h :: aux ()
    in
    Http.Header.of_list (aux ())
end

module Old_parser = struct
  let take_while1 p r =
    match Buf_read.take_while p r with "" -> raise End_of_file | x -> x

  let token =
    take_while1 (function
      | '0' .. '9'
      | 'a' .. 'z'
      | 'A' .. 'Z'
      | '!' | '#' | '$' | '%' | '&' | '\'' | '*' | '+' | '-' | '.' | '^' | '_'
      | '`' | '|' | '~' ->
          true
      | _ -> false)

  let ows = Buf_read.skip_while (function ' ' | '\t' -> true | _ -> false)
  let crlf = Buf_read.string "\r\n"
  let not_cr = function '\r' -> false | _ -> true

  let header =
    let open Eio.Buf_read.Syntax in
    let+ key = token <* Buf_read.char ':' <* ows
    and+ value = Buf_read.take_while not_cr <* crlf in
    (key, value)

  let http_headers r =
    let[@tail_mod_cons] rec aux () =
      match Buf_read.peek_char r with
      | Some '\r' ->
          crlf r;
          []
      | _ ->
          let h = header r in
          h :: aux ()
    in
    Http.Header.of_list (aux ())
end

(* An Eio.Flow.source that keeps feeding the same data again and again. *)
let flow_of_string (txt : string) : Eio.Flow.source =
  let txt = Cstruct.of_string txt in
  object
    inherit Eio.Flow.source
    val mutable data = [ txt ]

    method read_into dst =
      let got, src = Cstruct.fillv ~dst ~src:data in
      if Cstruct.lenv src = 0 then data <- [ txt ] else data <- src;
      got
  end

let headers =
  "Host: localhost:8080\r\n\
   User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:97.0) Gecko/20100101 \
   Firefox/97.0\r\n\
   Accept: \
   text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8\r\n\
   Accept-Language: en-US,en;q=0.5\r\n\
   Accept-Encoding: gzip, deflate\r\n\
   DNT: 1\r\n\
   Connection: keep-alive\r\n\
   Upgrade-Insecure-Requests: 1\r\n\
   Sec-Fetch-Dest: document\r\n\
   Sec-Fetch-Mode: navigate\r\n\
   Sec-Fetch-Site: cross-site\r\n\
   Cache-Control: max-age=0\r\n\
   \r\n"

let reader () = flow_of_string headers |> Buf_read.of_flow ~max_size:max_int
let exec_old_parser () = ignore (Old_parser.http_headers @@ reader ())
let exec_new_parser () = ignore (New_parser.http_headers @@ reader ())

open Core_bench

let () =
  let _flow =
    Eio.Flow.string_source headers |> Buf_read.of_flow ~max_size:max_int
  in
  Command_unix.run
    (Bench.make_command
       [
         Core_bench.Bench.Test.create ~name:"Old_parser" exec_old_parser;
         Core_bench.Bench.Test.create ~name:"New_parser" exec_new_parser;
       ])
