open! Import

type t [@@deriving sexp, compare]

val of_string : string -> t
val to_string : t -> string
