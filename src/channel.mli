open! Import

type t =
  | SMS
  | MMS
  | Email

val of_string : string -> t
val to_string : t -> string
