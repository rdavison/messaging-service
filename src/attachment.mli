open! Import

type t = Uri_sexp.t [@@deriving sexp, compare]

val of_string : string -> t
val of_jsonb : string -> t list
val to_jsonb : t list -> string
