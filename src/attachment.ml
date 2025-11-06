open! Import

type t = Uri_sexp.t [@@deriving sexp, compare]

let of_string s = Uri.of_string s

let of_jsonb s =
  let json = Yojson.Basic.from_string s in
  let lst = Yojson.Basic.Util.to_list json in
  List.map lst ~f:(fun json -> of_string (Yojson.Basic.Util.to_string json))
;;

let to_jsonb lst =
  let json = `List (List.map lst ~f:(fun uri -> `String (Uri.to_string uri))) in
  Yojson.Basic.to_string json
;;
