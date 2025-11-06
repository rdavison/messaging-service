open! Import

type t =
  | Inbound
  | Outbound
[@@deriving sexp, compare]

let of_string s =
  match String.lowercase s with
  | "inbound" -> Inbound
  | "outbound" -> Outbound
  | other -> failwithf "BUG: Unable to parse Inbound_or_outbound: %s" other ()
;;

let to_string = function
  | Inbound -> "inbound"
  | Outbound -> "outbound"
;;
