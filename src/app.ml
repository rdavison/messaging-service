open! Import

module Config = struct
  type t = { db : Db.Config.t } [@@deriving sexp]
end

type t = { config : Config.t }

let with_db_conn t ~f = Db.with_conn t.config.db ~f >>| Or_error.join

let query ?parameters t ~sql ~parse_row =
  let rows = ref [] in
  let%bind result =
    with_db_conn t ~f:(fun conn ->
      Postgres_async.query conn ?parameters sql ~handle_row:(fun ~column_names ~values ->
        let row = parse_row ~column_names ~values in
        rows := row :: !rows))
  in
  Or_error.ok_exn result;
  return (List.rev !rows)
;;

let query1 ?parameters t ~sql ~parse_row =
  let%map rows = query ?parameters t ~sql ~parse_row in
  match rows with
  | [ x ] -> x
  | _ ->
    failwithf
      "BUG: Expected exactly 1 result, got %d. Query: %s. Params: %s"
      (List.length rows)
      sql
      ([%sexp_of: string option array option] parameters |> Sexp.to_string)
      ()
;;

let query0 ?parameters t ~sql =
  let%map result =
    with_db_conn t ~f:(fun conn ->
      Postgres_async.query_expect_no_data conn ?parameters sql)
  in
  Or_error.ok_exn result
;;

let query1_opt ?parameters t ~sql ~parse_row =
  match%map query ?parameters t ~sql ~parse_row with
  | [] -> None
  | [ x ] -> Some x
  | rows ->
    failwithf
      "BUG: Expected 0 or 1 query result, got %d. Query %s. Params: %s"
      (List.length rows)
      sql
      ([%sexp_of: string option array option] parameters |> Sexp.to_string)
      ()
;;
