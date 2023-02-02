(** [Client] is a HTTP client *)

type t

val make :
  ?timeout:Eio.Time.Timeout.t ->
  ?buf_read_initial_size:int ->
  ?buf_write_initial_size:int ->
  ?pipeline_requests:bool ->
  unit ->
  t

val buf_write_initial_size : t -> int
(** [buf_write_initial_size] is the buffered writer iniital size. *)

val buf_read_initial_size : t -> int
(** [buf_read_initial_size] is the buffered reader initial size. *)

val timeout : t -> Eio.Time.Timeout.t
(** [timeout] specifies total time limit for establishing a connection, calling
    a request and getting a response back.

    A client request is cancelled if the specified timeout limit is exceeded. *)

val pipeline_requests : t -> bool
(** [pipeline_requests t] returns [true] it [t] is configured to pipeline
    requests. [false] otherwise. *)

type response = Http.Response.t * Eio.Buf_read.t

val call :
  t -> conn:#Eio.Flow.two_way -> 'a Request.client_request -> 'a -> response

val with_call :
  t -> Eio.Net.t -> 'a Request.client_request -> 'a -> (response -> 'b) -> 'b
