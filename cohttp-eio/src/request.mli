(** [Request] is a HTTP Request. *)

(** [t] is a common request abstraction for {!type:server} and {!type:client}. *)
class virtual ['a] t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : string
  end

type host_port = string * int option
(** [host_port] is a tuple of [(host, Some port)]. *)

val version : _ #t -> Http.Version.t
(** [version t] is the HTTP version of request [t]. *)

val headers : _ #t -> Http.Header.t
(** [headers t] is headers associated with request [t]. *)

val meth : 'a #t -> 'a Method.t
(** [meth t] is request method for [t].*)

val resource : _ #t -> string
(** [resource] is request resource uri for [t], e.g. "/home/products/123". *)

val supports_chunked_trailers : _ #t -> bool
(** [supports_chunked_trailers t] is [true] is request [t] has header "TE:
    trailers". It is [false] otherwise. *)

val keep_alive : _ #t -> bool
(** [keep_alive t] is [true] if [t] has header "Connection: keep-alive" or if
    "Connection" header is missing and the HTTP version is 1.1. It is [false] if
    header "Connection: close" exists. *)

(** {1 Client Request}

    A HTTP client request that is primarily constructed and used by
    {!module:Client}. *)
class virtual ['a] client :
  object
    inherit ['a] t
    constraint 'a = #Body.writer
    method virtual body : 'a
    method virtual host : string
    method virtual port : int option
  end

val client :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?port:int ->
  host:string ->
  resource:string ->
  'a Method.t ->
  'a ->
  'a client
(** [client ~host ~resource meth body] is an instance of {!class:client} where
    [body] is a {!class:Body.writer}. *)

val body : (#Body.writer as 'a) #client -> 'a
(** [body r] is request body for client [r]. *)

val client_host_port : _ #client -> host_port
(** [client_host_port r] is the [host] and [port] for client request [r]. *)

type url = string
(** [url] is a HTTP URI value with host information.

    {[
      "www.example.com/products"
    ]} *)

val get : url -> Body.none client
(** [get url] is a client request [r] configured with HTTP request method
    {!val:Method.Get}.

    {[
      let r = Request.get "www.example.com/products/a/"
    ]}
    @raise Invalid_argument if [url] is invalid. *)

val head : url -> Body.none client
(** [head url] is a client request [r] configured with HTTP request method
    {!val:Method.Head}.

    {[
      let r = Request.head "www.example.com/products/"
    ]}
    @raise Invalid_argument if [url] is invalid. *)

val post : (#Body.writer as 'a) -> url -> 'a client
(** [post body url] is a client request [r] configured with HTTP request method
    {!val:Method.Post} and with request body [body]. A header "Content-Length"
    is added with suitable value in the request header.

    {[
      let body = Body.conten_writer ~content:"Hello, World!" ~content_type:"text/plain" in
      let r = Request.post body "www.example.com/product/purchase/123"
    ]}
    @raise Invalid_argument if [url] is invalid. *)

val post_form_values : (string * string list) list -> url -> Body.writer client
(** [post_form_values form_fields url] is a client request [r] configured with
    HTTP request method {!val:Method.Post}. The body [form_fields] is a list of
    form fields [(name, values)]. [form_fields] is percent encoded before being
    transmitted. Two HTTP headers are added to the request: "Content-Length" and
    "Content-Type" with value "application/x-www-form-urlencoded".

    {[
      let form_fields = [ ("field1", [ "a"; "b" ]) ] in
      Request.post_form_values form_fields "www.example.com/product/update"
    ]}
    @raise Invalid_argument if [url] is invalid. *)

val write : 'a #client -> Eio.Buf_write.t -> unit
(** [write r buf_write] writes client request [r] using [buf_write]. *)

(** {1 Server Request} *)

(** [server] is a request that is primarily constructed and used in
    {!module:Server}.

    A [server] is also a sub-type of {!class:Body.reader}.*)
class virtual server :
  object
    inherit [Body.none] t
    inherit Body.reader
    method virtual client_addr : Eio.Net.Sockaddr.stream
    method virtual buf_read : Eio.Buf_read.t
  end

val buf_read : #server -> Eio.Buf_read.t
(** [buf_read r] is a buffered reader that can read request [r] body. *)

val client_addr : #server -> Eio.Net.Sockaddr.stream
(** [client_addr r] is the remove client address for request [r]. *)

val server :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  resource:string ->
  Body.none Method.t ->
  Eio.Net.Sockaddr.stream ->
  Eio.Buf_read.t ->
  server
(** [server meth client_addr buf_read] is an instance of {!class:server}. *)

val parse_server : Eio.Net.Sockaddr.stream -> Eio.Buf_read.t -> server
(** [parse_server client_addr buf_read] parses a server request [r] given a
    buffered reader [buf_read]. *)
