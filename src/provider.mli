open! Import

type t =
  | Sendgrid
  | Twilio
  | Xillio
  | Messaging_provider
[@@deriving sexp, compare, enumerate]

val to_string : t -> string
val of_string : string -> t
val of_endpoint_kind : Endpoint.Kind.t -> t

module Message : sig
  module Id : Identifiable.S
end
