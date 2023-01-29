type host = string * int option
type resource_path = string
type 'a header = 'a Header.header = ..

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

let header : Header.Codec.t =
  object
    method header : type a. Header.lname -> a header =
      fun nm ->
        match (nm :> string) with
        | "host" -> Obj.magic Host
        | "user-agent" -> Obj.magic User_agent
        | _ -> Header.Codec.v#header nm

    method equal : type a b. a header -> b header -> (a, b) Header.eq option =
      fun a b ->
        match (a, b) with
        | Host, Host -> Some Eq
        | User_agent, User_agent -> Some Eq
        | _ -> Header.Codec.v#equal a b

    method decoder : type a. a header -> a Header.decoder =
      function
      | Host -> host_decoder
      | User_agent -> Fun.id
      | hdr -> Header.Codec.v#decoder hdr

    method encoder : type a. a header -> a Header.encoder =
      function
      | Host -> host_encoder
      | User_agent -> Fun.id
      | hdr -> Header.Codec.v#encoder hdr

    method name : type a. a header -> Header.name =
      function
      | Host -> Header.canonical_name "host"
      | User_agent -> Header.canonical_name "user-agent"
      | hdr -> Header.Codec.v#name hdr
  end
