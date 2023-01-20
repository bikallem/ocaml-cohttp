type host = string * int option
type resource_path = string
type 'a header = ..

module Header = Header.Make (struct
  type 'a t = 'a header = ..
end)

type 'a header +=
  | Content_length = Header.Content_length
  | Transfer_encoding = Header.Transfer_encoding
  | H = Header.H
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

let header =
  object
    inherit Header.header_definition

    method v : type a. string -> a header =
      function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | hdr -> Header.header#v hdr

    method decoder : type a. a Header.header -> a Header.decoder =
      function
      | Host -> host_decoder
      | User_agent -> Fun.id
      | hdr -> Header.header#decoder hdr

    method encoder : type a. a header -> Header.name * a Header.encoder =
      function
      | Host -> ("Host", host_encoder)
      | User_agent -> ("User_agent", Fun.id)
      | hdr -> Header.header#encoder hdr
  end

type t = {
  headers : Header.t;
  meth : Http.Method.t;
  version : Http.Version.t;
  resource_path : resource_path;
}

let make ?(header = header) ?(meth = `GET) ?(version = `HTTP_1_1) resource_path
    =
  let headers = Header.make ~header () in
  { headers; meth; version; resource_path }

let meth t = t.meth
let version t = t.version
let resource_path t = t.resource_path
let headers t = t.headers
