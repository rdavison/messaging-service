open! Import

module Kind = struct
  type t =
    | Email
    | Phone
    | Cross
  [@@deriving sexp, compare]

  let to_string = function
    | Email -> "email"
    | Phone -> "phone"
    | Cross -> "cross"
  ;;

  let of_string s =
    match String.lowercase s with
    | "email" -> Email
    | "phone" -> Phone
    | "cross" -> Cross
    | other -> failwithf "BUG: Unexpected endpoint kind: %s" other ()
  ;;
end

type t =
  | Email of Email.t
  | Phone of Phone.t
[@@deriving sexp, compare]

let kind = function
  | Email _ -> Kind.Email
  | Phone _ -> Phone
;;

let payload_to_db = function
  | Email email -> Email.to_string email
  | Phone phone -> Phone.Number.to_string phone.number
;;

let parse ?phone_channel kind payload =
  match kind with
  | Kind.Phone ->
    Phone
      { Phone.number = Phone.Number.of_string payload
      ; channel = Option.map phone_channel ~f:Phone.Channel.of_string |> Option.value_exn
      }
  | Email -> Email (Email.of_string payload)
  | Cross as kind ->
    failwithf "BUG: Unsupported endpoint kind: %s" (Kind.to_string kind) ()
;;

let phone_channel = function
  | Email _ -> None
  | Phone { channel; _ } -> Some channel
;;
