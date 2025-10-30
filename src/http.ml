open! Import

let respond_string ~content_type ?headers ?status s =
  let headers = Cohttp.Header.add_opt headers "Content-Type" content_type in
  Cohttp_async.Server.respond_string ~headers ?status s
;;

let respond_bad_request ?headers () =
  let headers = Cohttp.Header.add_opt headers "Content-Type" "text/plain" in
  Cohttp_async.Server.respond_string ~headers ~status:`Bad_request "Bad Request"
;;

let respond_internal_serevr_error ?headers () =
  let headers = Cohttp.Header.add_opt headers "Content-Type" "text/plain" in
  Cohttp_async.Server.respond_string
    ~headers
    ~status:`Internal_server_error
    "Internal Server Error"
;;
