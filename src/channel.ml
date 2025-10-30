open! Import

type t =
  | SMS
  | MMS
  | Email

let of_string s =
  match String.lowercase s with
  | "sms" -> SMS
  | "mms" -> MMS
  | "email" -> Email
  | other -> failwithf "BUG: Unknown channel: %s" other ()
;;

let to_string = function
  | SMS -> "sms"
  | MMS -> "mms"
  | Email -> "email"
;;
