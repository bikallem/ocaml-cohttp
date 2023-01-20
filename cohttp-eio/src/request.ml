type host = string * int option
type resource_path = string
type 'a header = ..

module H = Header.Make (struct
  type 'a t = 'a header = ..
end)

type 'a header +=
  | Content_length = H.Content_length
  | Transfer_encoding = H.Transfer_encoding
  | H = H.H
  | Host : host header
  | User_agent : string header

let host_decoder v =
  match String.split_on_char ':' v with
  | [ host; port ] -> (host, Some (int_of_string port))
  | host :: [] -> (String.trim host, None)
  | _ -> raise @@ Invalid_argument "invalid Host header value"

let host_encoder = function
  | host, Some port -> host ^ ":" ^ string_of_int port
  | host, None -> host

let header : H.header_definition =
  object
    method v : type a. string -> a header =
      function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | hdr -> H.header#v hdr

    method decoder : type a. a H.header -> a H.decoder =
      function
      | Host -> host_decoder
      | User_agent -> Fun.id
      | hdr -> H.header#decoder hdr

    method encoder : type a. a header -> H.name * a H.encoder =
      function
      | Host -> ("Host", host_encoder)
      | User_agent -> ("User_agent", Fun.id)
      | hdr -> H.header#encoder hdr
  end

type t = {
  headers : H.t;
  meth : Http.Method.t;
  version : Http.Version.t;
  resource_path : resource_path;
}

module Header = struct
  let req_header = header

  include H

  let empty ?(header = req_header) () = H.empty header

  let of_seq ?header seq =
    let h = empty ?header () in
    H.of_seq h seq
end

let make ?(headers = Header.empty ()) ?(meth = `GET) ?(version = `HTTP_1_1)
    resource_path =
  { headers; meth; version; resource_path }

let meth t = t.meth
let version t = t.version
let resource_path t = t.resource_path
let headers t = t.headers
