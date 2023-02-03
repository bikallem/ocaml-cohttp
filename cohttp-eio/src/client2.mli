(** [Client] is a HTTP client.

    It implements connection caching based on [host] and [port]. Therefore TCP
    connections for the same [host,port] are reused if one is available in the
    cache. Alternately, the caching mechanism can be avoided by directly using
    {!val:call}.

    See {{!convenience} convenience} for common client use cases. *)

type t
(** [t] is a HTTP client. It encapsulates client buffered reader/writer initial
    size , whether to batch requests and timeout setting.

    It is safe for concurrent usage.

    See {!val:make}. *)

val make :
  ?timeout:Eio.Time.Timeout.t ->
  ?buf_read_initial_size:int ->
  ?buf_write_initial_size:int ->
  ?batch_requests:bool ->
  Eio.Switch.t ->
  Eio.Net.t ->
  t

val buf_write_initial_size : t -> int
(** [buf_write_initial_size] is the buffered writer iniital size. *)

val buf_read_initial_size : t -> int
(** [buf_read_initial_size] is the buffered reader initial size. *)

val timeout : t -> Eio.Time.Timeout.t
(** [timeout] specifies total time limit for establishing a connection, calling
    a request and getting a response back.

    A client request is cancelled if the specified timeout limit is exceeded. *)

val batch_requests : t -> bool
(** [batch_requests t] returns [true] it [t] is configured to batch requests.
    [false] otherwise. *)

(** {1 Call} *)

type response = Http.Response.t * Eio.Buf_read.t

val call : conn:#Eio.Flow.two_way -> 'a Request.client_request -> response
(** [call conn req] makes a HTTP client call using connection [conn] and request
    [req]. It returns a {!type:response} upon a successfull call.

    {i Note} The function doesn't use connection cache or implement request
    redirection or cookie functionality.

    @raise Eio.Exn.Io in cases of connection errors. *)

(** {1:convenience Convenience calls} *)

val get : t -> string -> response
(** [get t url] is [response] after making a HTTP GET request call to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val head : t -> string -> response
(** [head t url] is [response] after making a HTTP HEAD request call to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val post : t -> #Body2.writer -> string -> response
(** [post t body url] is [response] after making a HTTP POST request call with
    body [body] to [url].

    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)

val post_form_values : t -> (string * string) list -> Request.url -> response
(** [post_form_values t form_values url] is [response] after making a HTTP POST
    request call to [url] with form values [form_values].

    {[
      Client.post_form_values t
        [ ("field_a", "val a"); ("field_b", "val b") ]
        url
    ]}
    @raise Invalid_argument if [url] is invalid.
    @raise Eio.Exn.Io in cases of connection errors. *)
