open! Import

let not_found_html =
  {|
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>404 Not Found</title>
  </head>
  <body>
    <h1>404 Not Found</h1>
  </body>
</html>
|}
;;

let html =
  {|
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <script defer src="main.js"></script>
    <title> To-do List </title>
  </head>

  <body>
    <div id="app"></div>
  </body>
</html>
|}
;;

let with_json ~(body : Cohttp_async.Body.t) (req : Cohttp.Request.t) ~f =
  let%bind body = Cohttp_async.Body.to_string body in
  match Cohttp.Header.get_media_type req.headers with
  | Some "application/json" ->
    (match Yojson.Basic.from_string body with
     | json -> f json
     | exception Yojson.Json_error _msg -> Http.respond_bad_request ())
  | Some _ | None -> Http.respond_bad_request ()
;;

let handle_api_messages_sms
      (app : App.t)
      ~(body : Cohttp_async.Body.t)
      _inet
      (req : Cohttp.Request.t)
  =
  match req.meth with
  | `POST ->
    with_json ~body req ~f:(fun json ->
      json |> Api.Messages.Sms.outbound_of_json |> Api.Messages.Sms.handle_post app)
  | #Cohttp.Code.meth -> Http.respond_bad_request ()
;;

let handler (app : App.t) ~(body : Cohttp_async.Body.t) inet (req : Cohttp.Request.t) =
  Log.info "Handling request\n";
  let path = Uri.path (Cohttp.Request.uri req) in
  match path with
  | "" | "/" | "/index.html" -> Http.respond_string ~content_type:"text/html" html
  | "/api/messages/sms" -> handle_api_messages_sms app ~body inet req
  | _ -> Http.respond_string ~content_type:"text/html" ~status:`Not_found not_found_html
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
  let poll () =
    let%bind unprocessed_messages = Message.get_unprocessed app in
    Deferred.List.iter ~how:`Sequential unprocessed_messages ~f:(fun (id, _message) ->
      let%map status = Message.process id ~app in
      Log.info "Message: %s => %s" (Message.Id.to_string id) (Status.to_string status))
  in
  Deferred.forever () poll;
  Deferred.unit
;;
