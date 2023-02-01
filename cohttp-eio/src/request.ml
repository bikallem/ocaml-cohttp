module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

type resource = string

(** [request] is the common request object *)
class virtual ['a] t =
  object (_ : 'b)
    constraint 'a = #Body2.writer
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : string
  end

class virtual ['a] client_request =
  object
    inherit ['a] t
    method virtual host : string
    method virtual port : int option
  end

let client_request ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) ?port
    (meth : (#Body2.writer as 'a) Method.t) host resource =
  object
    inherit [#Body2.writer as 'a] client_request
    val headers = headers
    method version = version
    method headers = headers
    method meth = meth
    method resource = resource
    method host = host
    method port = port
  end

let version (t : _ #t) = t#version
let headers (t : _ #t) = t#headers
let meth (t : _ #t) = t#meth
let resource (t : _ #t) = t#resource
let client_host_port (t : _ #client_request) = (t#host, t#port)

let write ?(pipeline_requests = false) (t : _ #client_request) body writer =
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
    match Body2.header body with
    | Some (nm, v) -> Http.Header.add headers nm v
    | None -> headers
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
  Body2.write body writer;
  if not pipeline_requests then Buf_write.flush writer
