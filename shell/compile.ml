open Common

module A = Ast
module O = Opcode

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let rec split_at_non_assign = function
  | A.Assign (val1, val2, cmd) ->
      let (a,b) = split_at_non_assign cmd in
      (val1, val2)::a, b
  | b -> [], b


(*****************************************************************************)
(* Compilation algorithm *)
(*****************************************************************************)

(* todo: need pass eflag in all the subfunc below? 
 * maybe now that all types are mutually recursive.
 *)
let outcode_seq seq eflag emit idx =

  let rec xseq seq eflag =
   (* less set iflast *)
    seq |> List.iter (fun x -> xcmd x eflag)
  
  and xcmd cmd eflag =
    match cmd with
    | A.Simple (w, ws) -> 
        emit (O.F O.Mark);
        xwords ws eflag;
        xword w eflag;
        emit (O.F O.Simple);
        if eflag then emit (O.F O.Eflag);

    | A.Assign (val1, val2, cmd) ->
        let all_assigns, cmd = 
          split_at_non_assign (A.Assign (val1, val2, cmd)) in
        (match cmd with
        (* A=b; *)
        | A.EmptyCommand -> 
            all_assigns |> List.iter (fun (val1, val2) ->
              emit (O.F O.Mark);
              xword val2 eflag;
              emit (O.F O.Mark);
              xword val1 eflag;
              emit (O.F O.Assign);
            )

        (* A=b cmd; *)
        | _ -> 
            all_assigns |> List.iter (fun (val1, val2) ->
              emit (O.F O.Mark);
              xword val2 eflag;
              emit (O.F O.Mark);
              xword val1 eflag;
              emit (O.F O.Local);
            );
            xcmd cmd eflag;
            all_assigns |> List.iter (fun (_, _) ->
              emit (O.F O.Unlocal);
            )
        )
        
    | _ -> failwith ("TODO: " ^ Dumper.s_of_cmd cmd)

  and xword w eflag =
    match w with
    | A.Word (s, _quoted) ->
        emit (O.F O.Word);
        emit (O.S s);

    | A.List ws ->
        xwords ws eflag

    | _ -> failwith ("TODO: " ^ Dumper.s_of_value w)

  and xwords ws eflag =
    ws |> List.rev |> List.iter (fun w -> xword w eflag);
    
  in
  xseq seq eflag

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let compile seq =

  (* a growing array *)
  let codebuf = ref [| |] in
  let len_codebuf = ref 0 in
  (* pointer in codebuf *)
  let idx = ref 0 in

  let codebuf_template = Array.create 100 (O.I 0) in

  let emit x =
    (* grow the array if needed *)
    if !idx = !len_codebuf then begin
      len_codebuf := !len_codebuf + 100;
      codebuf := Array.append !codebuf codebuf_template;
    end;

    !codebuf.(!idx) <- x;
    incr idx
  in
  
  outcode_seq seq !Flags.eflag emit idx;
  emit (O.F O.Return);
  (* less: O.F O.End *)
  (* less: heredoc, readhere() *)

  Array.sub !codebuf 0 !idx
  |> (fun x -> if !Flags.dump_opcodes then pr2 (Dumper.s_of_codevec x); x)
