(* TODO Should the client also enforce this spec https://www.rfc-editor.org/rfc/rfc9112#section-6.3 *)
type 'a t =
  | Continue : Body.none t  (** 100 *)
  | Switching_protocols : Body.none t  (** 101 *)
  | Processing : Body.none t  (** 102 *)
  | Checkpoint : Body.none t  (** 103 *)
  | OK : 'a t  (** 200 *)
  | Created : 'a t  (** 201 *)
  | Accepted : 'a t  (** 202 *)
  | Non_authoritative_information : 'a t  (** 203 *)
  | No_content : Body.none t  (** 204 *)
  | Reset_content : 'a t  (** 205 *)
  | Partial_content : 'a t  (** 206 *)
  | Multi_status : 'a t  (** 207 *)
  | Already_reported : 'a t  (** 208 *)
  | Im_used : 'a t  (** 226 *)
  (* 3xx *)
  | Multiple_choices : 'a t  (** 300 *)
  | Moved_permanently : 'a t  (** 301 *)
  | Found : 'a t  (** 302 *)
  | See_other : 'a t  (** 303 *)
  | Not_modified : Body.none t  (** 304 *)
  | Use_proxy : 'a t  (** 305 *)
  | Switch_proxy : 'a t  (** 306 *)
  | Temporary_redirect : 'a t  (** 307 *)
  | Permanent_redirect : 'a t  (** 308 *)
  (* 4x *)
  | Bad_request : 'a t  (** 400 *)
  | Unauthorized : 'a t  (** 401 *)
  | Payment_required : 'a t  (** 402 *)
  | Forbidden : 'a t  (** 403 *)
  | Not_found : 'a t  (** 404 *)
  | Method_not_allowed : 'a t  (** 405 *)
  | Not_acceptable : 'a t  (** 406 *)
  | Proxy_authentication_required : 'a t  (** 407 *)
  | Request_timeout : 'a t  (** 408 *)
  | Conflict : 'a t  (** 409 *)
  | Gone : 'a t  (** 410 *)
  | Length_required : 'a t  (** 411 *)
  | Precondition_failed : 'a t  (** 412 *)
  | Request_entity_too_large : 'a t  (** 413 *)
  | Request_uri_too_long : 'a t  (** 414 *)
  | Unsupported_media_type : 'a t  (** 415 *)
  | Requested_range_not_satisfiable : 'a t  (** 416 *)
  | Expectation_failed : 'a t  (** 417 *)
  | Misdirected_request : 'a t  (** 421 *)
  | Unprocessable_entity : 'a t  (** 422 *)
  | Locked : 'a t  (** 423 *)
  | Failed_dependency : 'a t  (** 424 *)
  | Too_early : 'a t  (** 425 *)
  | Upgrade_required : 'a t  (** 426 *)
  | Precondition_required : 'a t  (** 428 *)
  | Too_many_requests : 'a t  (** 429 *)
  | Request_header_fields_too_large : 'a t  (** 431 *)
  | Unavailable_for_legal_reasons : 'a t  (** 451 *)
  (* 5xx *)
  | Internal_server_error : 'a t  (** 500 *)
  | Not_implemented : 'a t  (** 501 *)
  | Bad_gateway : 'a t  (** 502 *)
  | Service_unavailable : 'a t  (** 503 *)
  | Gateway_timeout : 'a t  (** 504 *)
  | Http_version_not_supported : 'a t  (** 505 *)
  | Variant_also_negotiates : 'a t  (** 506 *)
  | Insufficient_storage : 'a t  (** 507 *)
  | Loop_detected : 'a t  (** 508 *)
  | Network_authentication_required : 'a t  (** 511 *)
(*   | Code : int * string -> 'a t *)

let of_int : int -> 'a t = function
  | 100 -> Obj.magic Continue
  | 101 -> Obj.magic Switching_protocols
  | 102 -> Obj.magic Processing
  | 103 -> Obj.magic Checkpoint
  | 200 -> Obj.magic OK
  | 201 -> Obj.magic Created
  | 202 -> Obj.magic Accepted
  | 203 -> Obj.magic Non_authoritative_information
  | 204 -> Obj.magic No_content
  | 205 -> Obj.magic Reset_content
  | 206 -> Obj.magic Partial_content
  | 207 -> Obj.magic Multi_status
  | 208 -> Obj.magic Already_reported
  | 226 -> Obj.magic Im_used
  | 300 -> Obj.magic Multiple_choices
  | 301 -> Obj.magic Moved_permanently
  | 302 -> Obj.magic Found
  | 303 -> Obj.magic See_other
  | 304 -> Obj.magic Not_modified
  | 305 -> Obj.magic Use_proxy
  | 306 -> Obj.magic Switch_proxy
  | 307 -> Obj.magic Temporary_redirect
  | 308 -> Obj.magic Permanent_redirect
  | 400 -> Obj.magic Bad_request
  | 401 -> Obj.magic Unauthorized
  | 402 -> Obj.magic Payment_required
  | 403 -> Obj.magic Forbidden
  | 404 -> Obj.magic Not_found
  | 405 -> Obj.magic Method_not_allowed
  | 406 -> Obj.magic Not_acceptable
  | 407 -> Obj.magic Proxy_authentication_required
  | 408 -> Obj.magic Request_timeout
  | 409 -> Obj.magic Conflict
  | 410 -> Obj.magic Gone
  | 411 -> Obj.magic Length_required
  | 412 -> Obj.magic Precondition_failed
  | 413 -> Obj.magic Request_entity_too_large
  | 414 -> Obj.magic Request_uri_too_long
  | 415 -> Obj.magic Unsupported_media_type
  | 416 -> Obj.magic Requested_range_not_satisfiable
  | 417 -> Obj.magic Expectation_failed
  | 422 -> Obj.magic Unprocessable_entity
  | 423 -> Obj.magic Locked
  | 424 -> Obj.magic Failed_dependency
  | 426 -> Obj.magic Upgrade_required
  | 428 -> Obj.magic Precondition_required
  | 429 -> Obj.magic Too_many_requests
  | 431 -> Obj.magic Request_header_fields_too_large
  | 500 -> Obj.magic Internal_server_error
  | 501 -> Obj.magic Not_implemented
  | 502 -> Obj.magic Bad_gateway
  | 503 -> Obj.magic Service_unavailable
  | 504 -> Obj.magic Gateway_timeout
  | 505 -> Obj.magic Http_version_not_supported
  | 506 -> Obj.magic Variant_also_negotiates
  | 507 -> Obj.magic Insufficient_storage
  | 508 -> Obj.magic Loop_detected
  | code -> failwith ("Invalid status code " ^ string_of_int code)

let to_int : type a. a t -> int = function
  | Continue -> 100
  | Switching_protocols -> 101
  | Processing -> 102
  | Checkpoint -> 103
  | OK -> 200
  | Created -> 201
  | Accepted -> 202
  | Non_authoritative_information -> 203
  | No_content -> 204
  | Reset_content -> 205
  | Partial_content -> 206
  | Multi_status -> 207
  | Already_reported -> 208
  | Im_used -> 226
  | Multiple_choices -> 300
  | Moved_permanently -> 301
  | Found -> 302
  | See_other -> 303
  | Not_modified -> 304
  | Use_proxy -> 305
  | Switch_proxy -> 306
  | Temporary_redirect -> 307
  | Permanent_redirect -> 308
  | Bad_request -> 400
  | Unauthorized -> 401
  | Payment_required -> 402
  | Forbidden -> 403
  | Not_found -> 404
  | Method_not_allowed -> 405
  | Not_acceptable -> 406
  | Proxy_authentication_required -> 407
  | Request_timeout -> 408
  | Conflict -> 409
  | Gone -> 410
  | Length_required -> 411
  | Precondition_failed -> 412
  | Request_entity_too_large -> 413
  | Request_uri_too_long -> 414
  | Unsupported_media_type -> 415
  | Requested_range_not_satisfiable -> 416
  | Expectation_failed -> 417
  | Misdirected_request -> 421
  | Unprocessable_entity -> 422
  | Locked -> 423
  | Failed_dependency -> 424
  | Too_early -> 425
  | Upgrade_required -> 426
  | Precondition_required -> 428
  | Too_many_requests -> 429
  | Request_header_fields_too_large -> 431
  | Unavailable_for_legal_reasons -> 451
  | Internal_server_error -> 500
  | Not_implemented -> 501
  | Bad_gateway -> 502
  | Service_unavailable -> 503
  | Gateway_timeout -> 504
  | Http_version_not_supported -> 505
  | Variant_also_negotiates -> 506
  | Insufficient_storage -> 507
  | Loop_detected -> 508
  | Network_authentication_required -> 511

let equal (type a b) (a : a t) (b : b t) =
  let a = to_int a and b = to_int b in
  a = b

let to_string : type a. a t -> string =
 fun t ->
  let code = to_int t in
  string_of_int code ^ " " ^ Http.Status.reason_phrase_of_code code

let pp fmt t = Format.fprintf fmt "%s" (to_string t)
