(** HTTP Status codes.

    Some status codes require that body not exist in the response message.

    https://www.rfc-editor.org/rfc/rfc9112#section-6.3

    1. Any response to a HEAD request and any response with a 1xx
    (Informational), 204 (No Content), or 304 (Not Modified) status code is
    always terminated by the first empty line after the header fields,
    regardless of the header fields present in the message, and thus cannot
    contain a message body or trailer section.

    Status Codes are defined at
    {{:https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml}
    IANA HTTP Satus Codes}. *)
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

val equal : 'a t -> 'b t -> bool
val of_int : int -> 'a t
val to_string : _ t -> string
val pp : Format.formatter -> _ t -> unit
