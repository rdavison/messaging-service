open! Import

type t =
  | Inbound
  | Outbound

val of_string : string -> t
val to_string : t -> string
