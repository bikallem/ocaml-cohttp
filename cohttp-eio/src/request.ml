module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

type resource = string

(** [request] is the common request object *)
class t ?(version = `HTTP_1_1) ?(headers = Http.Header.init ()) resource =
  object
    val headers = headers
    method version : Http.Version.t = version
    method headers : Http.Header.t = headers
    method resource : string = resource
    method update_headers headers = {<headers>}
  end

type host = string * int option

class ['a] client_request ?version ?headers meth host resource =
  object
    constraint 'a = #Body2.writer
    inherit t ?version ?headers resource
    method meth : 'a Method.t = meth
    method host : host = host
  end

let make_client_request ?version ?headers meth host resource =
  new client_request ?version ?headers meth host resource

let version (t : #t) = t#version
let headers (t : #t) = t#headers
let resource (t : #t) = t#resource
let meth (client_request : _ #client_request) = client_request#meth
let host (client_request : _ #client_request) = client_request#host
let update_headers (t : #t) headers = t#update_headers headers
