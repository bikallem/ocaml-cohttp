type host = string * int option
type resource_path = string

module Request_header = struct
  type 'a Header.header +=
    | Host : host Header.header
    | User_agent : string Header.header

  type 'a t = 'a Header.header

  let equal : type a b. a t -> b t -> (a, b) Header.eq option =
   fun t t' ->
    match (t, t') with
    | Host, Host -> Some Eq
    | User_agent, User_agent -> Some Eq
    | _, _ -> None

  let id (type a) (hdr : a Header.header) =
    match hdr with
    | Host -> Some "host"
    | User_agent -> Some "user-agent"
    | _ -> None

  let t : type a. Header.lowercase_id -> a Header.header option = function
    | "host" -> Obj.magic Host
    | "user-agent" -> Obj.magic User_agent
    | _ -> None

  let decoder _hdr = None
  let encoder _hdr = None
end

module Make (H : Header.HEADER) = struct
  module Header = Header.Make (H)

  type t = {
    headers : Header.t;
    meth : Http.Method.t;
    version : Http.Version.t;
    resource_path : resource_path;
  }

  let make ?(meth = `GET) ?(version = `HTTP_1_1) ?(headers = Header.empty) _host
      resource_path =
    { headers; meth; version; resource_path }

  let meth t = t.meth
  let version t = t.version
  let resource_path t = t.resource_path
  let headers t = t.headers
end

(** Default request with *)
module R = struct
  type 'a Header.header +=
    | Content_length = Header.Content_length
    | Transfer_encoding = Header.Transfer_encoding
    | Hdr = Header.Hdr
    | Host = Request_header.Host
    | User_agent = Request_header.User_agent

  include Make (Request_header)
end
