type host = string * int option
type resource_path = string
type 'a header = 'a Header.header = ..

type 'a Header.header +=
  | Content_length = Header.Content_length
  | Transfer_encoding = Header.Transfer_encoding
  | H = Header.H
  | Host : host Header.header
  | User_agent : string Header.header

let host_decoder v =
  match String.split_on_char ':' v with
  | [ host; port ] -> (host, Some (int_of_string port))
  | host :: [] -> (String.trim host, None)
  | _ -> raise @@ Invalid_argument "invalid Host header value"

let host_encoder = function
  | host, Some port -> host ^ ":" ^ string_of_int port
  | host, None -> host

class virtual header_definition = Header.header_definition

let header =
  object
    inherit Header.header_definition

    method v : type a. string -> a header =
      function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | hdr -> Header.header#v hdr

    method decoder : type a. a header -> a Header.decoder =
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

let add h a t =
  let headers = Header.add h a t.headers in
  { t with headers }

let add_lazy h lazy_val t =
  let headers = Header.add_lazy h lazy_val t.headers in
  { t with headers }

let add_value h v t =
  let headers = Header.add_value h v t.headers in
  { t with headers }

let find h t = Header.find h t.headers
let find_opt h t = Header.find_opt h t.headers
let iter f t = Header.iter f t.headers

let map f t =
  let headers = Header.map f t.headers in
  { t with headers }

let fold f t = Header.fold f t.headers

let remove h t =
  let headers = Header.remove h t.headers in
  { t with headers }

let update h f t =
  let headers = Header.update h f t.headers in
  { t with headers }

let add_name_value ~name ~value t =
  let headers = Header.add_name_value ~name ~value t.headers in
  { t with headers }
