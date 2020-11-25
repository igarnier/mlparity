open Alcotest
open Geth
open Geth_lwt

(* open Mlparity
 * 
 * module Test_Deploy (X : sig end) = struct
 *   let genesis =
 *     GethInit.Genesis.
 *       { config=
 *           {chain_id= 0; homestead_block= 0; eip155_block= 0; eip158_block= 0};
 *         alloc= [];
 *         coinbase= "0x0000000000000000000000000000000000000000";
 *         difficulty= 1;
 *         extra_data= "";
 *         gas_limit= 0x2fefd8;
 *         nonce= 0x107;
 *         mix_hash=
 *           "0x0000000000000000000000000000000000000000000000000000000000000000";
 *         parent_hash=
 *           "0x0000000000000000000000000000000000000000000000000000000000000000";
 *         timestamp= 0 }
 * 
 *   let conf =
 *     let open GethInit in
 *     { genesis_block= genesis;
 *       network_id= 8798798;
 *       root_directory= "priveth";
 *       data_subdir= "data";
 *       source_subdir= "source" }
 * 
 *   let password =
 *     Printf.printf "password: %!" ;
 *     Ssh_client.Easy.read_secret ()
 * 
 *   let ilias_on_xps13 =
 *     {GethInit.ip_address= "127.0.0.1"; ssh_port= 22; login= "ilias"; password}
 * 
 *   let _ =
 *     let enode = GethInit.start_no_discover conf ilias_on_xps13 in
 *     Printf.printf "enode: %s\n" enode
 * end *)

module Test_Asm (X : sig end) = struct
  let code =
    let open Asm in
    [ { name= Some "block0";
        instrs=
          [ Push {width= 1}; Lit (Evm.literal_of_int 0); Push {width= 1};
            Lit (Evm.literal_of_int 1); Add; Jumpi {block= "block0"} ] } ]

  let result = Asm.to_bytecode code
  let string_result = Evm.dump result
  let _ = Printf.printf "%s\n%!" string_result

  let example =
    let open Evm in
    [ Instr PUSH1; Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD; Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr PUSH1;
      Literal (Evm.literal_of_int 5); Instr ADD ]

  let _ = Printf.printf "%s\n%!" Evm.(dump (deploy example))
end

module A = Test_Asm ()

let compile fn () = ignore (Compile.to_json ~filename:fn)
let contracts = ["helloworld.sol"]
let compile = List.map (fun s -> (s, `Quick, compile s)) contracts

let jsons =
  [ "IERC20.json"; "IUniswapV2Callee.json"; "IUniswapV2ERC20.json";
    "IUniswapV2Factory.json"; "IUniswapV2Pair.json" ]

let logs =
  [ {|{"removed":false,"logIndex":"0x23","transactionIndex":"0x19","transactionHash":"0xef1b5f072b1ad94164395eb20098af29017d3a5b536122f584f786bf4f6b0547","blockHash":"0x80ca3b76ebf523f09186f28d13286710656dfca1f7acd3df81cf31c22f843766","blockNumber":"0xac4863","address":"0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984","data":"0x000000000000000000000000000000000000000000000001d790872df723f800","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000001ad3252d94343997a32fd23e45ea5b0bad8a6b7f","0x000000000000000000000000376976bfe2002a4bff84ab11beac2a62a0642a90"]}|}
  ]

module X = Json_encoding.Make (Json_repr.Yojson)
module ST = SolidityTypes

let ofJson e json () =
  try ignore (X.destruct e json)
  with Json_encoding.Cannot_destruct (_path, exn) ->
    Format.kasprintf failwith "%a"
      (Json_encoding.print_error ?print_unknown:None)
      exn

let contract =
  List.map
    (fun s -> (s, `Quick, ofJson Contract.simple (Yojson.Safe.from_file s)))
    jsons

let log =
  List.map
    (fun s ->
      (s, `Quick, ofJson Types.Log.encoding (Yojson.Safe.from_string s)))
    logs

let parse_tests =
  [ "int256"; "uint256"; "int32"; "uint32"; "address"; "bool"; "fixed";
    "fixed12x12"; "ufixed12x12"; "string"; "function"; "int256[]";
    "(int256,int256)" ]

let typs =
  let roundtrip s =
    let roundtrip = SolidityTypes.(to_string (of_string_exn s)) in
    check string s s roundtrip in
  [("basic", `Quick, fun () -> List.iter roundtrip parse_tests)]

let svs =
  SolidityValue.
    [ int 256 Z.zero; int 256 Z.one; int 256 Z.minus_one; string "";
      uint 256 Z.(of_int 256); uint 256 Z.(of_int 12121);
      uint 256 (Z.of_int (1 lsl 16)); uint 256 (Z.of_int (1 lsl 24));
      tuple [string ""; string ""]; tuple [string ""]; tuple [int 256 Z.zero];
      farray [int 256 Z.zero; int 256 Z.zero] (ST.Int 256);
      varray [int 256 Z.zero; int 256 Z.zero] (ST.Int 256) ]

let vs =
  let open Bitstring in
  let open SolidityValue in
  let with_bit_sets l =
    let buf = zeroes_bitstring 256 in
    List.iter (fun i -> set buf i) l ;
    buf in
  [(uint 256 Z.zero, with_bit_sets []); (uint 256 Z.one, with_bit_sets [255])]

let z = testable Z.pp_print Z.equal

let values =
  let open SolidityValue in
  let sv = testable pp equal in
  let roundtrip v =
    let roundtrip = encode v |> decode v.t in
    check sv (show v) v roundtrip in
  let onetrip (expected, v) =
    let v = decode expected.t v in
    check sv "" expected v in
  [ ("roundtrip", `Quick, fun () -> List.iter roundtrip svs);
    ("onetrip", `Quick, fun () -> List.iter onetrip vs) ]

let bs =
  let pp ppf x =
    Format.fprintf ppf "%a" Hex.pp
      (Hex.of_string (Bitstring.string_of_bitstring x)) in
  testable pp Bitstring.equals

let packeds =
  SolidityValue.
    [ (int 16 Z.minus_one, `Hex "ffff");
      ( tuple
          [ nbytes
              (Hex.to_string (`Hex "deadbeef00000000000000000000000000000000"));
            nbytes
              (Hex.to_string
                 (`Hex
                   "000000000000000000000000feed000000000000000000000000000000000000"))
          ],
        `Hex
          "deadbeef00000000000000000000000000000000000000000000000000000000feed000000000000000000000000000000000000"
      );
      ( tuple
          [ int 16 Z.minus_one; bytes "\x42"; uint 16 (Z.of_int 3);
            string "Hello, world!" ],
        `Hex "ffff42000348656c6c6f2c20776f726c6421" ) ]

let packed =
  let open SolidityValue in
  let roundtrip (v, e) =
    let e = Bitstring.bitstring_of_string (Hex.to_string e) in
    check bs (show v) e (packed v) in
  [("basic", `Quick, fun () -> List.iter roundtrip packeds)]

let create2s =
  [ ( `Hex "deadbeef00000000000000000000000000000000",
      `Hex "000000000000000000000000feed000000000000000000000000000000000000",
      `Hex "00",
      `Hex "D04116cDd17beBE565EB2422F2497E06cC1C9833" );
    ( `Hex "0000000000000000000000000000000000000000",
      `Hex "0000000000000000000000000000000000000000000000000000000000000000",
      `Hex "00",
      `Hex "4D1A2e2bB4F88F0250f26Ffff098B0b30B26BF38" ) ]

let create2 =
  let open Types in
  let roundtrip (addr, salt, initCode, res) =
    let addr = Address.of_hex addr in
    let salt = Hex.to_string salt in
    let initCode = ABI.keccak (Hex.to_string initCode) in
    let res = Hex.to_string res in
    let x = ABI.create2 ~addr ~salt ~initCode in
    check Alcotest.string "" res x in
  [("basic", `Quick, fun () -> List.iter roundtrip create2s)]

let () =
  Alcotest.run "geth"
    [ ("types", typs); ("values", values); ("packed", packed);
      ("create2", create2); ("compile", compile); ("contract", contract);
      ("log", log) ]
