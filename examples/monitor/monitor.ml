open Lwt.Infix
open Geth
open Geth_lwt
open Types
open Rpc

(* A program that monitors a geth node and calls callbacks whenever blocks are mined. *)

type block_predicate = Block.t -> bool
type state = {block_number: int; blocks: Block.t list}

let poll_new_block uri state =
  Eth.get_block_by_number ~uri ~at_time:(`block (state.block_number + 1))
  >|= function
  | None -> None
  | Some block -> (
    match block.Block.number with
    | None -> failwith "block has no number!?"
    | Some n ->
        if n <> state.block_number + 1 then failwith "block number mismatch"
        else
          Some
            {block_number= state.block_number + 1; blocks= block :: state.blocks}
    )

let process_action action_table new_block =
  let rec loop action_table =
    match action_table with
    | [] -> ()
    | (pred, act) :: tl -> if pred new_block then act new_block else loop tl
  in
  loop action_table

let rec iter_blocks period uri state f =
  poll_new_block uri state
  >>= function
  | None -> Lwt_unix.sleep period >>= fun () -> iter_blocks period uri state f
  | Some ({blocks= new_block :: _; _} as new_state) ->
      f new_block >>= fun () -> iter_blocks period uri new_state f
  | _ -> Lwt.fail_with "poll_loop: impossible state reached!?"

let default_action block =
  Printf.printf "block #%s, #tx %d, tstamp %s\n%!"
    (Option.fold ~none:"pending" ~some:string_of_int block.Block.number)
    (List.length block.Block.transactions)
    (Z.to_string block.Block.timestamp) ;
  Lwt.return_unit

let main () =
  let uri = "http://localhost:8545" in
  Rpc.switch_debug () ;
  Eth.block_number ~uri
  >>= fun block_number ->
  let state = {block_number; blocks= []} in
  iter_blocks 0.5 uri state default_action

let () = Lwt_main.run (main ())
