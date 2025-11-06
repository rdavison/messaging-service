open! Import

module Config : sig
  type t = { db : Db.Config.t } [@@deriving sexp]
end

type t = { config : Config.t }

val with_db_conn
  :  t
  -> f:(Postgres_async.t -> 'a Deferred.Or_error.t)
  -> 'a Deferred.Or_error.t

val query
  :  ?parameters:string option array
  -> t
  -> sql:string
  -> parse_row:(column_names:string array -> values:string option array -> 'a)
  -> 'a list Deferred.t

val query1
  :  ?parameters:string option array
  -> t
  -> sql:string
  -> parse_row:(column_names:string array -> values:string option array -> 'a)
  -> 'a Deferred.t

val query0 : ?parameters:string option array -> t -> sql:string -> unit Deferred.t

val query1_opt
  :  ?parameters:string option array
  -> t
  -> sql:string
  -> parse_row:(column_names:string array -> values:string option array -> 'a)
  -> 'a option Deferred.t
