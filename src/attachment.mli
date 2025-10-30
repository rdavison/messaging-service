open! Import

type t = Uri of Uri.t

val of_string : string -> t
val of_jsonb : string -> t list
val to_jsonb : t list -> string
