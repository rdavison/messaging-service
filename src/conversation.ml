open! Import

module Id = struct
  type t = string

  let to_string t = t

  module Private = struct
    let of_string s = s
  end
end

type t =
  { key : string
  ; channel : string
  }

let parse_row row =
  match Iarray.to_array row with
  | [| Some key; Some channel |] -> { key; channel }
  | _ -> failwith "BUG: Unable to parse row"
;;

let save ({ key; channel } : t) ~app =
  App.query1
    app
    ~sql:
      {|
        INSERT INTO conversations
          (
            id,
            key,
            channel
          )
        VALUES
          (
            uuid_generate_v4(),
            $1,
            $2
          )
        RETURNING id
        |}
    ~parameters:[| (* $1 *) Some key; (* $2 *) Some channel |]
    ~parse_row:(fun ~column_names:_ ~values ->
      match Iarray.to_array values with
      | [| Some id |] -> Id.Private.of_string id
      | _ -> assert false)
;;

let get_or_create ?(topic = "") ~app ~participants ~channel () =
  let unique_key =
    let participants_sorted =
      Set.to_list participants |> List.sort ~compare:Participant.compare
    in
    List.map participants_sorted ~f:Participant.to_string |> String.concat ~sep:","
  in
  let parse_row ~column_names:_ ~values =
    match Iarray.to_array values with
    | [| Some id |] -> Id.Private.of_string id
    | _ -> assert false
  in
  match%bind
    App.query
      app
      ~sql:{|SELECT id FROM conversations WHERE participants = $1 AND channel = $2|}
      ~parameters:[| Some unique_key; Some (Channel.to_string channel) |]
      ~parse_row
  with
  | [ id ] -> return id
  | [] ->
    let sql =
      {|
        INSERT INTO conversations (channel, participants, topic)
        VALUES ($1::channel, $2::text, $3::text)
        RETURNING id
      |}
    in
    let parameters =
      [| Some (Channel.to_string channel)
       ; Some unique_key
       ; (match channel with
          | Email -> Some topic
          | SMS | MMS -> None)
      |]
    in
    App.query1 app ~sql ~parameters ~parse_row
  | _ -> failwith "BUG: Unexpected number of rows returned"
;;
