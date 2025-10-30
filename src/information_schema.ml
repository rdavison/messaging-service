open! Import

type t =
  { schema : string
  ; table : string
  ; column : string
  ; typ : string
  }
[@@deriving sexp]

let query conn ~f =
  let sql =
    {|
      SELECT table_schema, table_name, column_name, data_type
      FROM information_schema.columns
      WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
      ORDER BY table_schema, table_name, ordinal_position
    |}
  in
  Postgres_async.query conn sql ~handle_row:(fun ~column_names:_ ~values ->
    match Iarray.to_list values with
    | [ Some schema; Some table; Some column; Some typ ] ->
      f { schema; table; column; typ }
    | _ -> ())
;;
