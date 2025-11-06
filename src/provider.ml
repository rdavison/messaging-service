open! Import

type t =
  | Sendgrid
  | Twilio
  | Xillio
  | Messaging_provider
[@@deriving sexp, compare, enumerate]

let of_string s =
  match String.lowercase s with
  | "sendgrid" -> Sendgrid
  | "twilio" -> Twilio
  | "xillio" -> Xillio
  | "messaging_provider" -> Messaging_provider
  | other -> failwithf "BUG: Unexpected provider: %s" other ()
;;

let to_string = function
  | Sendgrid -> "sendgrid"
  | Twilio -> "twilio"
  | Xillio -> "xillio"
  | Messaging_provider -> "messaging_provider"
;;

let of_endpoint_kind kind =
  match kind with
  | Endpoint.Kind.Email -> Sendgrid
  | Phone -> Twilio
  | Cross -> Twilio
;;

module Message = struct
  module Id : Identifiable.S = String
end
