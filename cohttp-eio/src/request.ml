module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

(** [request] is the common request object *)
class virtual ['a] t =
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : string
    method virtual body : 'a
  end

class virtual ['a] client_request =
  object
    inherit ['a] t
    constraint 'a = #Body2.writer
    method virtual host : string
    method virtual port : int option
  end

let client_request ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) ?port
    (meth : (#Body2.writer as 'a) Method.t) ~host ~resource body =
  object
    inherit [#Body2.writer as 'a] client_request
    val headers = headers
    method version = version
    method headers = headers
    method meth = meth
    method resource = resource
    method host = host
    method port = port
    method body = body
  end

let version (t : _ #t) = t#version
let headers (t : _ #t) = t#headers
let meth (t : _ #t) = t#meth
let resource (t : _ #t) = t#resource

type host_port = string * int option

let client_host_port (t : _ #client_request) = (t#host, t#port)

let write (t : _ #client_request) body writer =
  let headers =
    if not (Http.Header.mem t#headers "Host") then
      let host =
        match t#port with
        | Some port -> t#host ^ ":" ^ string_of_int port
        | None -> t#host
      in
      Http.Header.add t#headers "Host" host
    else t#headers
  in
  let headers =
    Http.Header.add_unless_exists headers "User-Agent" "cohttp-eio"
  in
  let headers = Http.Header.add headers "TE" "trailers" in
  let headers = Http.Header.add headers "Connection" "TE" in
  let headers =
    match Body2.headers body with
    | [] -> headers
    | l -> Http.Header.add_list headers l
  in
  let headers = Http.Header.clean_dup headers in
  let headers = Http.Header.Private.move_to_front headers "Host" in
  let meth = Method.to_string t#meth in
  let version = Http.Version.to_string t#version in
  Buf_write.string writer meth;
  Buf_write.char writer ' ';
  Buf_write.string writer t#resource;
  Buf_write.char writer ' ';
  Buf_write.string writer version;
  Buf_write.string writer "\r\n";
  Rwer.write_headers writer headers;
  Buf_write.string writer "\r\n";
  Body2.write body writer

type url = string

let parse_url url =
  if String.starts_with ~prefix:"https" url then
    raise @@ Invalid_argument "url: https protocol not supported";
  let url =
    if
      (not (String.starts_with ~prefix:"http" url))
      && not (String.starts_with ~prefix:"//" url)
    then "//" ^ url
    else url
  in
  let u = Uri.of_string url in
  let host, port =
    match (Uri.host u, Uri.port u) with
    | None, _ -> raise @@ Invalid_argument "invalid url: host not defined"
    | Some host, port -> (host, port)
  in
  (host, port, Uri.path_and_query u)

let get url =
  let host, port, resource = parse_url url in
  client_request ?port Method.Get ~host ~resource Body2.none

let head url =
  let host, port, resource = parse_url url in
  client_request ?port Method.Head ~host ~resource Body2.none

let post body url =
  let host, port, resource = parse_url url in
  client_request ?port Method.Post ~host ~resource body

class virtual ['a] server_request =
  object
    inherit ['a #Body2.reader] t
    constraint 'a = 'a #Body2.reader
    method virtual meth : ('a Body2.reader as 'b) Method.t
    method virtual host : string option
    method virtual port : int option
  end

let server_request ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) ?port
    ?host (meth : ('a #Body2.reader as 'a) Method.t) ~resource body =
  object
    inherit ['a #Body2.reader as 'a] server_request
    val headers = headers
    method version = version
    method headers = headers
    method meth = meth
    method resource = resource
    method host = host
    method port = port
    method body = body
  end

let server_host_port (t : _ #server_request) =
  Option.map (fun host -> (host, t#port)) t#host
