open! Import

type failed =
  { code : int
  ; reason : string
  }
[@@deriving sexp, compare]

type retry =
  { attempt : int
  ; after : Time_float_unix.Stable.With_utc_sexp.V2.t
  }
[@@deriving sexp, compare]

type t =
  | Outbox
  | OK
  | Failed of failed
  | Retry of retry
[@@deriving sexp, compare]

type db = string * string option

let to_db = function
  | Outbox -> "outbox", None
  | OK -> "ok", None
  | Failed failed -> "failed", Some ([%sexp_of: failed] failed |> Sexp.to_string)
  | Retry retry -> "retry", Some ([%sexp_of: retry] retry |> Sexp.to_string)
;;

let of_db (tag, payload) =
  match tag with
  | "outbox" -> Outbox
  | "ok" -> OK
  | "failed" ->
    let payload = Option.value_exn payload in
    Failed (Sexp.of_string payload |> failed_of_sexp)
  | "retry" ->
    let payload = Option.value_exn payload in
    Retry (Sexp.of_string payload |> retry_of_sexp)
  | other -> failwithf "BUG: Unexpected delivery_status: %s" other ()
;;
