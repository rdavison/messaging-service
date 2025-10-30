open! Import

type t = string [@@deriving sexp, compare]

let of_string t = t
let to_string t = t
