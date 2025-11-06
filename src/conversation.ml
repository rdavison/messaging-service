open! Import
module Id : Identifiable.S = Int64

module Kind = struct
  type t =
    | Phone
    | Email
  [@@deriving sexp]
end

type t =
  { source : Endpoint.t
  ; target : Endpoint.t
  }
[@@deriving sexp, compare]

let to_json (id, { source; target }) =
  `Assoc
    (List.filter_opt
       [ Some ("id", `String (Id.to_string id))
       ; Some ("endpoint_kind", `String (Endpoint.kind source |> Endpoint.Kind.to_string))
       ; (match source with
          | Email _ -> None
          | Phone { channel; _ } ->
            Some ("channel", `String (Phone.Channel.to_string channel)))
       ; Some ("endpoint_source", `String (Endpoint.payload_to_db source))
       ; Some ("endpoint_target", `String (Endpoint.payload_to_db target))
       ])
;;

module Db = struct
  type t =
    { id : Id.t
    ; source : Endpoint.t
    ; target : Endpoint.t
    ; created_at : Time_ns_unix.t
    ; modified_at : Time_ns_unix.t
    }
  [@@deriving sexp, compare]
end

module Tbl = struct
  let columns_wrappers =
    [ "endpoint_kind", Fn.id
    ; "phone_channel", Fn.id
    ; "endpoint_source", Fn.id
    ; "endpoint_target", Fn.id
    ]
  ;;

  let columns = List.map columns_wrappers ~f:fst |> String.concat ~sep:","

  let _insert_values =
    List.mapi columns_wrappers ~f:(fun i (_, f) -> f (sprintf "$%d" (i + 1)))
    |> String.concat ~sep:","
  ;;

  module Parameters = struct
    let _conversation ({ source; target } : t) =
      [| Some (Endpoint.kind source |> Endpoint.Kind.to_string)
       ; (match source with
          | Email _ -> None
          | Phone { channel; _ } -> Some (Phone.Channel.to_string channel))
       ; Some (Endpoint.payload_to_db source)
       ; Some (Endpoint.payload_to_db target)
      |]
    ;;

    let id x = [| Some (Id.to_string x) |]
  end

  module Parse_row = struct
    let id ~column_names:_ ~values =
      match values with
      | [| Some id |] -> Id.of_string id
      | _ -> assert false
    ;;

    let conversation ~column_names:_ ~values =
      match values with
      | [| Some endpoint_kind
         ; phone_channel
         ; Some endpoint_source
         ; Some endpoint_target
        |] ->
        let endpoint_kind = Endpoint.Kind.of_string endpoint_kind in
        { source = Endpoint.parse ?phone_channel endpoint_kind endpoint_source
        ; target = Endpoint.parse ?phone_channel endpoint_kind endpoint_target
        }
      | _ -> assert false
    ;;

    let id_conversation ~column_names ~values =
      match Array.length values > 1 with
      | false -> failwith "BUG: Expected array with length > 1"
      | true ->
        (match values.(0) with
         | None -> failwith "BUG: Did not receive an id as the first value"
         | Some id ->
           let id = Id.of_string id in
           let conversation =
             conversation
               ~column_names:(Array.slice column_names 1 0)
               ~values:(Array.slice values 1 0)
           in
           id, conversation)
    ;;
  end
end

let source_target (source : Endpoint.t) (target : Endpoint.t) ~(app : App.t) =
  let parameters =
    [| Some (Endpoint.kind source |> Endpoint.Kind.to_string)
     ; Endpoint.phone_channel source |> Option.map ~f:Phone.Channel.to_string
     ; Some (Endpoint.payload_to_db source)
     ; Some (Endpoint.payload_to_db target)
    |]
  in
  let parse_row =
    fun ~column_names:_ ~values ->
    match values with
    | [| Some id |] -> Id.of_string id
    | _ -> assert false
  in
  match%bind
    App.query1_opt
      app
      ~parameters
      ~parse_row
      ~sql:
        {|
          SELECT id FROM conversations 
          WHERE 
            endpoint_kind = $1 AND
            phone_channel IS NOT DISTINCT FROM $2 AND
            LEAST(endpoint_source, endpoint_target) = LEAST($3, $4) AND
            GREATEST(endpoint_source, endpoint_target) = GREATEST($3, $4)
        |}
  with
  | Some id -> return id
  | None ->
    App.query1
      app
      ~parameters
      ~parse_row
      ~sql:
        {|
          INSERT INTO conversations (
            endpoint_kind,
            phone_channel,
            endpoint_source,
            endpoint_target
          ) VALUES (
            $1,
            $2,
            $3,
            $4
          ) RETURNING id
        |}
;;

let get_by_id id ~app =
  App.query1
    app
    ~sql:(sprintf "SELECT %s FROM conversations WHERE id = $1" Tbl.columns)
    ~parameters:(Tbl.Parameters.id id)
    ~parse_row:Tbl.Parse_row.conversation
;;

let get_all app =
  App.query
    app
    ~sql:(sprintf "SELECT id,%s FROM conversations" Tbl.columns)
    ~parse_row:Tbl.Parse_row.id_conversation
;;

let id id ~app =
  App.query1_opt
    app
    ~sql:"SELECT id FROM conversations WHERE id = $1"
    ~parameters:[| Some id |]
    ~parse_row:Tbl.Parse_row.id
;;
