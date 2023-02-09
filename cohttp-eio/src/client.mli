(** [Client] is a HTTP client.

    It implements connection caching based on [host] and [port]. Therefore TCP
    connections for the same [host,port] are reused if one is available in the
    cache.

    Alternately, the caching mechanism can be avoided by using {!val:call}.

    See {{!common} common} for common client use cases. *)

type t
(** [t] is a HTTP client. It encapsulates client buffered reader/writer initial
    size , whether to batch requests and timeout setting.

    It is safe for concurrent usage.

    See {!val:make}. *)

val make :
  ?timeout:Eio.Time.Timeout.t ->
  ?read_initial_size:int ->
  ?write_initial_size:int ->
  Eio.Switch.t ->
  #Eio.Net.t ->
  t
(** [make sw net] is [t]. [net] is used to create/establish connections to
    server. [sw] is the client resource manager. All connections are
    automatically closed when [sw] goes out of scope or is cancelled.

    @param timeout
      total time limit for establishing connection, make a request and getting a
      response back from the server. However, this value doesn't include reading
      response body. Default is [Eio.Time.Timeout.none].
    @param read_initial_size
      initial client buffered reader size. Default is [0x1000].
    @param write_initial_size
      initial client buffered writer size. Default is [0x1000]. *)

(** {1:common Common}

    Common client use-cases optimized for convenience. *)

val get : t -> Request.url -> Response.client
(** [get t url] is [response] after making a HTTP GET request call to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val head : t -> Request.url -> Response.client
(** [head t url] is [response] after making a HTTP HEAD request call to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val post : t -> #Body.writer -> Request.url -> Response.client
(** [post t body url] is [response] after making a HTTP POST request call with
    body [body] to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val post_form_values :
  t -> (string * string list) list -> Request.url -> Response.client
(** [post_form_values t form_values url] is [response] after making a HTTP POST
    request call to [url] with form values [form_values].

    {[
      Client.post_form_values t
        [ ("field_a", [ "val a1"; "val a2" ]); ("field_b", [ "val b" ]) ]
        url
    ]}
    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

(** {1 Call} *)

val do_call : t -> 'a Request.client -> Response.client
(** [do_call t req] makes a HTTP request using [req] and returns
    {!type:response}.

    @raise Eio.Exn.Io in cases of connection errors. *)

val call : conn:#Eio.Flow.two_way -> 'a Request.client -> Response.client
(** [call conn req] makes a HTTP client call using connection [conn] and request
    [req]. It returns a {!type:response} upon a successfull call.

    {i Note} The function doesn't use connection cache or implement request
    redirection or cookie functionality.

    @raise Eio.Exn.Io in cases of connection errors. *)

(** {1 Client Configuration} *)

val buf_write_initial_size : t -> int
(** [buf_write_initial_size] is the buffered writer iniital size. *)

val buf_read_initial_size : t -> int
(** [buf_read_initial_size] is the buffered reader initial size. *)

val timeout : t -> Eio.Time.Timeout.t
(** [timeout] specifies total time limit for establishing a connection, calling
    a request and getting a response back.

    A client request is cancelled if the specified timeout limit is exceeded. *)
