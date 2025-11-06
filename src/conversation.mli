open! Import
module Id : Identifiable.S

module Kind : sig
  type t =
    | Phone
    | Email
  [@@deriving sexp]
end

type t =
  { source : Endpoint.t
  ; target : Endpoint.t
  }
[@@deriving sexp, compare]

val to_json : Id.t * t -> Yojson.Basic.t

module Db : sig
  type t =
    { id : Id.t
    ; source : Endpoint.t
    ; target : Endpoint.t
    ; created_at : Time_ns_unix.t
    ; modified_at : Time_ns_unix.t
    }
  [@@deriving sexp, compare]
end

val source_target : Endpoint.t -> Endpoint.t -> app:App.t -> Id.t Deferred.t
val get_by_id : Id.t -> app:App.t -> t Deferred.t
val get_all : App.t -> (Id.t * t) list Deferred.t
val id : string -> app:App.t -> Id.t option Deferred.t
