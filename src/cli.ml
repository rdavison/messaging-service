open! Import

let apiserver =
  Command.async
    ~summary:"Start web server"
    (let%map_open.Command port =
       flag "port" (optional_with_default 8080 int) ~doc:"port on which to serve"
     and db_config = Command.Param.return Db.Config.dev in
     fun () -> Server.main ~port ~db_config)
;;

let message_processor =
  Command.async
    ~summary:"Start message processor"
    (let%map_open.Command db_config = Command.Param.return Db.Config.dev in
     fun () -> Server.message_processor ~db_config)
;;
