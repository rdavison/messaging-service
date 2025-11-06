open! Import

type response = { id : Provider.Message.Id.t }

let provider = Provider.Sendgrid

let of_json json =
  let module U = Yojson.Basic.Util in
  json
  |> U.member "id"
  |> U.to_string_option
  |> Option.map ~f:(fun id -> { id = Provider.Message.Id.of_string id })
;;

let send (message : Message.t) ~(app : App.t) =
  ignore message;
  ignore app;
  let mocked_response_codes =
    [| `OK; `Too_many_requests; `Bad_request; `Unauthorized; `Not_found |]
  in
  let i = mocked_response_codes |> Array.length |> Random.int in
  match mocked_response_codes.(i) with
  | `OK ->
    Http.respond_string
      ~content_type:"application/json"
      (sprintf
         {|{"id": "sendgrid-%s"}|}
         (Uuid.create_random Random.State.default |> Uuid.to_string))
  | `Too_many_requests -> Http.respond_too_many_requests ()
  | `Bad_request -> Http.respond_bad_request ()
  | `Unauthorized -> Http.respond_unauthorized ()
  | `Not_found -> Http.respond_not_found ()
  | _ -> Http.respond_internal_server_error ()
;;

let send_and_transition_status ?after ?(attempt = 0) id message ~app =
  let%bind response, body = send message ~app in
  let status = Cohttp.Response.status response in
  let code = Cohttp.Code.code_of_status status in
  let after =
    match after with
    | None -> Time_float_unix.now ()
    | Some time -> time
  in
  let%bind provider_message_id, status =
    match status with
    | #Cohttp.Code.success_status ->
      let%map body = Cohttp_async.Body.to_string body in
      (match Cohttp.Header.get_media_type response.headers with
       | Some "application/json" ->
         (match Yojson.Basic.from_string body |> of_json with
          | None -> failwithf "BUG: Unable to parse response: %s" body ()
          | Some { id = provider_message_id } ->
            Some provider_message_id, Delivery_status.OK)
       | Some other -> failwithf "BUG: Expected json media type, got: %s" other ()
       | None -> failwith "BUG: Unexpeced media type: None")
    | #Cohttp.Code.server_error_status ->
      return (None, Delivery_status.Failed { code; reason = "Server Error" })
    | `Bad_request ->
      return (None, Delivery_status.Failed { code; reason = "Bad Request" })
    | #Cohttp.Code.client_error_status ->
      return (None, Delivery_status.Retry { attempt = attempt + 1; after })
    | #Cohttp.Code.redirection_status ->
      return (None, Delivery_status.Retry { attempt = attempt + 1; after })
    | #Cohttp.Code.informational_status ->
      return (None, Delivery_status.Failed { code; reason = "Unknown" })
    | `Code code -> return (None, Delivery_status.Failed { code; reason = "Unknown" })
  in
  let%bind () =
    match provider_message_id with
    | None -> Message.update_status id status ~app
    | Some provider_message_id ->
      Message.update_status id status ~app ~provider ~provider_message_id
  in
  return status
;;
