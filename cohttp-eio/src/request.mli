(** HTTP Request *)

type resource = string

(** [request] is a common request type. *)
class t :
  ?version:Http.Version.t
  -> ?headers:Http.Header.t
  -> resource
  -> object ('a)
       method version : Http.Version.t
       method headers : Http.Header.t
       method resource : resource
       method update_headers : Http.Header.t -> 'a
     end

type host = string * int option
(** [host] is a tuple of [(host,port)].

    [host] represents a server host - as ip address or domain name, e.g.
    www.example.org, www.reddit.com and 216.239.32.10.

    [port] represents a tcp/ip port value. *)

(** [client_request] is HTTP client request. *)
class ['a] client_request :
  ?version:Http.Version.t
  -> ?headers:Http.Header.t
  -> 'a Method.t
  -> host
  -> resource
  -> object
       constraint 'a = #Body2.writer
       inherit t
       method meth : 'a Method.t
       method host : host
     end

val make_client_request :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  'a Method.t ->
  host ->
  resource ->
  'a client_request

val version : #t -> Http.Version.t
val headers : #t -> Http.Header.t
val resource : #t -> resource
val meth : 'a #client_request -> 'a Method.t
val host : _ #client_request -> host
val update_headers : (#t as 'a) -> Http.Header.t -> 'a
