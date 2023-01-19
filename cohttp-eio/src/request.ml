type host = string * int option
type resource_path = string
type 'a header = 'a Header.header

type 'a Header.header +=
  | Content_length = Header.Content_length
  | Transfer_encoding = Header.Transfer_encoding
  | H = Header.H
  | Host : host Header.header
  | User_agent : string Header.header

let host_decoder v =
  match String.split_on_char ',' v with
  | [ host; port ] -> (host, Some (int_of_string port))
  | host :: [] -> (String.trim host, None)
  | _ -> raise @@ Invalid_argument "invalid Host header value"

let host_encoder = function
  | host, Some port -> host ^ ":" ^ string_of_int port
  | host, None -> host

let header_def =
  object
    inherit Header.header_definition

    method header : type a. string -> a header option =
      function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | _ -> None

    method equal : type a b. a header -> b header -> (a, b) Header.eq option =
      fun a b ->
        match (a, b) with
        | Host, Host -> Some Eq
        | User_agent, User_agent -> Some Eq
        | _, _ -> None

    method decoder : type a. a header -> a Header.decoder option =
      function
      | Host -> Some host_decoder | User_agent -> Some Fun.id | _ -> None

    method encoder : type a. a header -> (Header.name * a Header.encoder) option
        =
      function
      | Host -> Some ("Host", host_encoder)
      | User_agent -> Some ("User_agent", Fun.id)
      | _ -> None
  end

type t = {
  headers : Header.t;
  meth : Http.Method.t;
  version : Http.Version.t;
  resource_path : resource_path;
}

let make ?(meth = `GET) ?(version = `HTTP_1_1)
    ?(headers = Header.make ~header_def ()) resource_path =
  { headers; meth; version; resource_path }

let meth t = t.meth
let version t = t.version
let resource_path t = t.resource_path
let headers t = t.headers
