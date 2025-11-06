open! Import

let handler (app : App.t) ~(body : Cohttp_async.Body.t) inet (req : Cohttp.Request.t) =
  match%bind
    Monitor.try_with (fun () ->
      Log.info "Handling request\n";
      let path = Uri.path (Cohttp.Request.uri req) in
      match String.split ~on:'/' path with
      | "" :: "api" :: path -> Api.handler app ~body inet req ~path
      | _ -> Http.respond_not_found ())
  with
  | Ok res -> return res
  | Error exn ->
    Log.error "%s" (Exn.to_string exn);
    Http.respond_internal_server_error ()
;;

let main ~port ~db_config =
  let hostname = Unix.gethostname () in
  Log.info "Serving http://%s:%d/\n%!" hostname port;
  let app = { App.config = { db = db_config } } in
  let%bind server =
    let http_handler ~body inet req = handler app ~body inet req in
    Cohttp_async.Server.create
      ~on_handler_error:`Raise
      (Tcp.Where_to_listen.of_port port)
      http_handler
  in
  Cohttp_async.Server.close_finished server
;;

let message_processor ~db_config =
  let app = { App.config = { db = db_config } } in
  let rec loop () =
    Log.info "Polling for unprocessed messages\n";
    let%bind messages = Message.get_deliverable app in
    let count = List.length messages in
    Log.info "Got %d unprocessed messages\n" count;
    let%bind () =
      Deferred.List.iteri ~how:`Sequential messages ~f:(fun i (id, _message) ->
        Log.info "Processing message %d/%d\n" (i + 1) count;
        let%map status = Message_processor.transition_status id ~app in
        Log.info
          "New status for message with id: %s => %s\n"
          (Message.Id.to_string id)
          (Delivery_status.sexp_of_t status |> Sexp.to_string))
    in
    let%bind () = after (Time_float.Span.of_int_sec 2) in
    loop ()
  in
  loop ()
;;
