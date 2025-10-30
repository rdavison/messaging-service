open! Import

type t =
  | Phone_number of Phone_number.t
  | Email of Email.t
[@@deriving sexp, compare]

include Comparable.S with type t := t

val of_string : string -> t
val to_string : t -> string
