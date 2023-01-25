(* module type S = sig
     type t
     type host = string * int option
     type resource_path = string
     type 'a header = ..

     (** {1 Headers} *)

     module Header : Header.S with type 'a header = 'a header

     type 'a header +=
       | Content_length : int header
       | Transfer_encoding :
           [ `chunked | `compress | `deflate | `gzip ] list header
       | H : Header.lowercase_name -> Header.value header
             (** A generic header. See {!type:lowercase_name}. *)
       | Host : host header
       | User_agent : string header

     val header : Header.header_definition
     val meth : t -> Http.Method.t
     val version : t -> Http.Version.t
     val resource_path : t -> resource_path
     val headers : t -> Header.t
   end
*)

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

let header_codec =
  object
    inherit Header.codec as super

    method! v : type a. string -> a header =
      function
      | "host" -> Obj.magic Host
      | "user-agent" -> Obj.magic User_agent
      | hdr -> super#v hdr

    method! decoder : type a. a header -> a Header.decoder =
      function
      | Host -> host_decoder | User_agent -> Fun.id | hdr -> super#decoder hdr

    method! encoder : type a. a header -> Header.name * a Header.encoder =
      function
      | Host -> ("Host", host_encoder)
      | User_agent -> ("User_agent", Fun.id)
      | hdr -> super#encoder hdr
  end

(*
module Header = struct
  let req_header = header

  include H

  let empty ?(header = req_header) () = H.empty header

  let of_seq ?header seq =
    let h = empty ?header () in
    H.of_seq h seq
end
*)
