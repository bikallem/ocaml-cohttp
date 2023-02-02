(** [Client] is a HTTP client *)

class virtual t :
  object
    method virtual timeout : Eio.Time.Timeout.t
    (** [timeout] specifies total time limit for establishing a connection,
        calling a request and getting a response back.

        A client request is cancelled if the specified timeout limit is
        exceeded. *)

    method virtual buf_read_initial_size : int
    (** [buf_read_initial_size] is the buffered reader initial size. *)

    method virtual buf_write_initial_size : int
    (** [buf_write_initial_size] is the buffered writer iniital size. *)

    method virtual pipeline_requests : bool
  end

val v :
  ?timeout:Eio.Time.Timeout.t ->
  ?buf_read_initial_size:int ->
  ?buf_write_initial_size:int ->
  ?pipeline_requests:bool ->
  unit ->
  t

type response = Http.Response.t * Eio.Buf_read.t

val call :
  #t -> conn:#Eio.Flow.two_way -> 'a Request.client_request -> 'a -> response

val with_call :
  #t -> Eio.Net.t -> 'a Request.client_request -> 'a -> (response -> 'b) -> 'b
