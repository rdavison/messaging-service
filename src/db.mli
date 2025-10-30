open! Import

module Config : sig
  type t =
    { host : string
    ; port : int
    ; user : string
    ; password : string
    ; db : string
    }
  [@@deriving sexp]

  module Default : sig
    val host : string
    val port : int
    val user : string
    val password : string
    val db : string
  end

  val dev : t
end

val conn : Config.t -> Postgres_async.t Deferred.Or_error.t

val with_conn
  :  Config.t
  -> f:(Postgres_async.t -> 'res Deferred.t)
  -> 'res Deferred.Or_error.t
