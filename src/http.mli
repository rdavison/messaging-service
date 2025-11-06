open! Import

val respond_string
  :  ?content_type:string
  -> ?headers:Cohttp.Header.t
  -> ?status:[ Cohttp.Code.status | `Code of int ]
  -> string
  -> Cohttp_async.Server.response Deferred.t

val respond_json
  :  ?content_type:string
  -> ?headers:Cohttp.Header.t
  -> ?status:[ Cohttp.Code.status | `Code of int ]
  -> Yojson.Basic.t
  -> Cohttp_async.Server.response Deferred.t

val respond_bad_request
  :  ?headers:Cohttp.Header.t
  -> unit
  -> Cohttp_async.Server.response Deferred.t

val respond_too_many_requests
  :  ?headers:Cohttp.Header.t
  -> unit
  -> Cohttp_async.Server.response Deferred.t

val respond_not_found
  :  ?headers:Cohttp.Header.t
  -> unit
  -> Cohttp_async.Server.response Deferred.t

val respond_unauthorized
  :  ?headers:Cohttp.Header.t
  -> unit
  -> Cohttp_async.Server.response Deferred.t

val respond_internal_server_error
  :  ?headers:Cohttp.Header.t
  -> unit
  -> Cohttp_async.Server.response Deferred.t
