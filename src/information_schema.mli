open! Import

type t =
  { schema : string
  ; table : string
  ; column : string
  ; typ : string
  }
[@@deriving sexp]

val query : Postgres_async.t -> f:(t -> unit) -> unit Deferred.Or_error.t
