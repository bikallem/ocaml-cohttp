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

type host_port = string * int option

let version (t : _ #t) = t#version
let headers (t : _ #t) = t#headers
let meth (t : _ #t) = t#meth
let resource (t : _ #t) = t#resource
let body (t : _ #t) = t#body

class virtual ['a] client_request =
  object
    inherit ['a] t
    constraint 'a = #Body2.writer
    method virtual host : string
    method virtual port : int option
  end

let client_request ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) ?port
    ~host ~resource (meth : (#Body2.writer as 'a) Method.t) body =
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

let client_host_port (t : _ #client_request) = (t#host, t#port)
let write_headers w l = List.iter (fun (k, v) -> Rwer.write_header w k v) l

let write (t : _ #client_request) (body : #Body2.writer) writer =
  let headers =
    Http.Header.add_unless_exists t#headers "User-Agent" "cohttp-eio"
  in
  let headers = Http.Header.add headers "TE" "trailers" in
  let headers = Http.Header.add headers "Connection" "TE" in
  let headers = Http.Header.clean_dup headers in
  let meth = Method.to_string t#meth in
  let version = Http.Version.to_string t#version in
  Buf_write.string writer meth;
  Buf_write.char writer ' ';
  Buf_write.string writer t#resource;
  Buf_write.char writer ' ';
  Buf_write.string writer version;
  Buf_write.string writer "\r\n";
  (* The first header is a "Host" header. *)
  let host =
    match t#port with
    | Some port -> t#host ^ ":" ^ string_of_int port
    | None -> t#host
  in
  Rwer.write_header writer "Host" host;
  Rwer.write_headers writer headers;
  body#write_headers (write_headers writer);
  Buf_write.string writer "\r\n";
  body#write_body writer

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

let post_form_values form_values url =
  let body = Body2.form_values_writer form_values in
  post body url

class virtual ['a] server_request =
  object
    inherit ['a #Body2.reader] t
    constraint 'a = 'a #Body2.reader
    method virtual meth : ('a Body2.reader as 'b) Method.t
    method virtual host : string option
    method virtual port : int option
    method virtual client_addr : Eio.Net.Sockaddr.stream
  end

let server_request ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) ?port
    ?host ~resource client_addr (meth : ('a #Body2.reader as 'a) Method.t) body
    =
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
    method client_addr = client_addr
  end

let server_host_port (t : _ #server_request) =
  Option.map (fun host -> (host, t#port)) t#host
