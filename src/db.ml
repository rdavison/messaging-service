open! Import

module Config = struct
  type t =
    { host : string
    ; port : int
    ; user : string
    ; password : string
    ; db : string
    }
  [@@deriving sexp]

  module Default = struct
    let host = "messaging-service-db"
    let port = 5432
    let user = "messaging_user"
    let password = "messaging_password"
    let db = "messaging_service"
  end

  let dev =
    { host = Default.host
    ; port = Default.port
    ; user = Default.user
    ; password = Default.password
    ; db = Default.db
    }
  ;;
end

let conn { Config.host; port; user; password; db } =
  (* read connection params from env or defaults *)
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port (Host_and_port.create ~host ~port)
  in
  Postgres_async.connect ~server:where_to_connect ~user ~password ~database:db ()
;;

let with_conn { Config.host; port; user; password; db } ~f =
  (* read connection params from env or defaults *)
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port (Host_and_port.create ~host ~port)
  in
  Postgres_async.with_connection
    ~server:where_to_connect
    ~user
    ~password
    ~database:db
    ~on_handler_exception:`Raise
    f
;;
