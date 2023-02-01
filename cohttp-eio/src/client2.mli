type response = Http.Response.t * Eio.Buf_read.t

val call :
  ?pipeline_requests:bool ->
  conn:#Eio.Flow.two_way ->
  'a Request.client_request ->
  'a ->
  response

val with_response_call :
  Eio.Net.t -> 'a Request.client_request -> 'a -> (response -> 'b) -> 'b
