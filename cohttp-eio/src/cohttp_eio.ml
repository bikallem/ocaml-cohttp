module type HEADER = sig
  type name = string
  type value = string
  type lowercase_name = string

  exception Decoder_undefined of string
  exception Encoder_undefined of string

  type 'a decoder = value -> 'a
  type 'a encoder = 'a -> value
  type 'a header = ..

  class virtual header_definition :
    object
      method virtual v : lowercase_name -> 'a header
      method virtual decoder : 'a header -> 'a decoder
      method virtual encoder : 'a header -> name * 'a encoder
    end

  type t
  type binding = B : 'a header * 'a -> binding

  val empty : ?header:header_definition -> unit -> t
  val add : 'a header -> 'a -> t -> t
  val add_lazy : 'a header -> 'a Lazy.t -> t -> t
  val add_value : 'a header -> value -> t -> t
  val find : 'a header -> t -> 'a
  val find_opt : 'a header -> t -> 'a option
  val exists : (binding -> bool) -> t -> bool
  val iter : < f : 'a. 'a header -> 'a -> unit > -> t -> unit
  val map : < f : 'a. 'a header -> 'a -> 'a > -> t -> t
  val filter : < f : 'a. 'a header -> 'a -> bool > -> t -> t
  val fold : < f : 'a. 'a header -> 'a -> 'b -> 'b > -> t -> 'b -> 'b
  val remove : 'a header -> t -> t
  val update : 'a header -> ('a option -> 'a option) -> t -> t
  val length : t -> int
  val to_seq : t -> binding Seq.t
  val of_seq : ?header:header_definition -> binding Seq.t -> t

  (**/**)

  val add_name_value : name:name -> value:value -> t -> t
end

module Request = Request
module Body = Body
module Server = Server
module Client = Client
