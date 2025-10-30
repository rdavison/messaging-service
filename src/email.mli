open! Import

type t = string [@@deriving sexp, compare]

val of_string : string -> t
val to_string : t -> string
