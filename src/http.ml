open! Import

let respond_string ?(content_type = "text/plain") ?headers ?status s =
  let headers = Cohttp.Header.add_opt headers "Content-Type" content_type in
  Cohttp_async.Server.respond_string ~headers ?status s
;;

let respond_json ?(content_type = "application/json") ?headers ?status json =
  respond_string ~content_type ?headers ?status (Yojson.Basic.to_string json)
;;

let respond_bad_request ?headers () =
  respond_string ?headers ~status:`Bad_request "Bad Request"
;;

let respond_too_many_requests ?headers () =
  respond_string ?headers ~status:`Too_many_requests "Too Many Requests"
;;

let respond_not_found ?headers () = respond_string ?headers ~status:`Not_found "Not Found"

let respond_unauthorized ?headers () =
  respond_string ?headers ~status:`Unauthorized "Unauthorized"
;;

let respond_internal_server_error ?headers () =
  respond_string ?headers ~status:`Internal_server_error "Internal Server Error"
;;
