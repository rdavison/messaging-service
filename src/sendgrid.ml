open! Import

let send (message : Message.t) ~(app : App.t) =
  ignore message;
  ignore app;
  let mocked_response_codes =
    [| `OK; `Too_many_requests; `Bad_request; `Unauthorized; `Not_found |]
  in
  let i = mocked_response_codes |> Array.length |> Random.int in
  match mocked_response_codes.(i) with
  | `OK -> Http.respond_string ~content_type:"application/json" {|{"id": "abc123"}|}
  | `Too_many_requests -> Http.respond_too_many_requests ()
  | `Bad_request -> Http.respond_bad_request ()
  | `Unauthorized -> Http.respond_unauthorized ()
  | `Not_found -> Http.respond_not_found ()
  | _ -> Http.respond_internal_server_error ()
;;

let send_and_transition_status ?after ?(attempt = 0) id message ~app =
  let%bind response, _body = send message ~app in
  let status = Cohttp.Response.status response in
  let code = Cohttp.Code.code_of_status status in
  let after =
    match after with
    | None -> Time_ns_unix.now ()
    | Some time -> time
  in
  let status =
    match status with
    | #Cohttp.Code.success_status -> Delivery_status.OK
    | #Cohttp.Code.server_error_status -> Failed { code; reason = "Server Error" }
    | `Bad_request -> Failed { code; reason = "Bad Request" }
    | #Cohttp.Code.client_error_status -> Retry { attempt = attempt + 1; after }
    | #Cohttp.Code.redirection_status -> Retry { attempt = attempt + 1; after }
    | #Cohttp.Code.informational_status -> Failed { code; reason = "Unknown" }
    | `Code code -> Failed { code; reason = "Unknown" }
  in
  let%map () = Message.update_status id status ~app in
  status
;;
