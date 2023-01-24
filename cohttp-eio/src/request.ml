module type S = sig
  type t
  type host = string * int option
  type resource_path = string

  (** {1 Headers} *)

  type 'a header = ..

  type 'a header +=
    | Content_length : int header
    | Transfer_encoding :
        [ `chunked | `compress | `deflate | `gzip ] list header
    | H : string -> string header
    | Host : host header
    | User_agent : string header

  module type HEADER_DEFINITION =
    Header.HEADER_DEFINITION with type 'a t = 'a header

  module Header : Header.S with type 'a header = 'a header

  (** {1 Request Details} *)

  val meth : t -> Http.Method.t
  val version : t -> Http.Version.t
  val resource_path : t -> resource_path
  val headers : t -> Header.t
end

module T = struct
  type host = string * int option
  type resource_path = string
  type 'a header = 'a Header.Common_header.t = ..

  type 'a header +=
    | Content_length = Header.Common_header.Content_length
    | Transfer_encoding = Header.Common_header.Transfer_encoding
    | H = Header.Common_header.H
    | Host : host header
    | User_agent : string header

  module type HEADER_DEFINITION =
    Header.HEADER_DEFINITION with type 'a t = 'a header

  module Header_definition = struct
    type 'a t = 'a header = ..

    let v : type a. string -> a t = function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | hdr -> Header.Common_header.v hdr

    let compare : type a b. a t -> b t -> int =
     fun a b ->
      match (a, b) with
      | Host, Host -> 0
      | Host, _ -> -1
      | _, Host -> 1
      | User_agent, User_agent -> 0
      | User_agent, _ -> -1
      | _, User_agent -> 1
      | a, b -> Header.Common_header.compare a b

    let host_decoder v =
      match String.split_on_char ':' v with
      | [ host; port ] -> (host, Some (int_of_string port))
      | host :: [] -> (String.trim host, None)
      | _ -> raise @@ Invalid_argument "invalid Host header value"

    let host_encoder = function
      | host, Some port -> host ^ ":" ^ string_of_int port
      | host, None -> host

    let decoder : type a. a t -> a Header.decoder = function
      | Host -> host_decoder
      | User_agent -> Fun.id
      | hdr -> Header.Common_header.decoder hdr

    let encoder : type a. a t -> string * a Header.encoder = function
      | Host -> ("Host", host_encoder)
      | User_agent -> ("User-Agent", Fun.id)
      | hdr -> Header.Common_header.encoder hdr
  end

  module Header = Header.Make (Header_definition)
end

module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write
module Switch = Eio.Switch

module Server_request = struct
  include T

  type t = {
    headers : Header.t;
    meth : Http.Method.t;
    version : Http.Version.t;
    resource_path : string;
    reader : Buf_read.t;
    client_addr : Eio.Net.Sockaddr.stream;
  }

  let make ?(headers = Header.empty) ?(meth = `GET) ?(version = `HTTP_1_1)
      reader client_addr resource_path =
    { headers; meth; version; resource_path; reader; client_addr }

  let meth t = t.meth
  let version t = t.version
  let resource_path t = t.resource_path
  let headers t = t.headers
  let reader t = t.reader
  let client_addr t = t.client_addr
end
