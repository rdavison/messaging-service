open! Import

type t =
  | Inbound
  | Outbound
[@@deriving sexp, compare]

val of_string : string -> t
val to_string : t -> string
