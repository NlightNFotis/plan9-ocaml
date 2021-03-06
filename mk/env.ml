(* Copyright 2016 Yoann Padioleau, see copyright.txt *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* Content of variables (after full expansion and backquote resolution).
 * It should not contain any empty strings (but it can contain empty lists).
 *)
type values = string list

type t = {
  vars         : (string, values) Hashtbl.t;
  internal_vars: (string, values) Hashtbl.t;

  vars_we_set: (string, bool) Hashtbl.t;
}

let mk_vars = [
  "target";
  "prereq";
  "stem";

  (* todo: alltargets, newprereq ... 
  *)
]

(* invariant *)
let check_values xs = 
  xs |> List.iter (fun s ->
    if s = ""
    then raise (Impossible (spf "empty string in values"))
  )
  
(*****************************************************************************)
(* Debug *)
(*****************************************************************************)
let dump_env env =
  env.vars |> Hashtbl.iter (fun k v ->
    pr2 (spf "%s -> %s" k (Common.dump v));
  )


(*****************************************************************************)
(* Functions *)
(*****************************************************************************)

(* less: could take the readenv function as a parameter? *)
let initenv () =
  let internal = 
    mk_vars |> List.map (fun k -> k,[]) |> Hashtbl_.of_list in
  let vars = 
    Shellenv.read_environment () |> List_.exclude (fun (s, _) ->
      (* when you use mk recursively, the environment might contain
       * a $stem from a parent mk process.
       *)
      Hashtbl.mem internal s
    ) |> Hashtbl_.of_list
  in

  (* for recursive mk *)
  let mkflags = 
    Sys.argv |> Array.fold_left (fun acc s ->
      if s =~ "^-"
      then s::acc
      else acc
    ) []
  in
  Hashtbl.add vars "MKFLAGS" (List.rev mkflags);

  (* less: extra checks and filtering on read_environment? *)
  { vars          = vars;
    internal_vars = internal;
    vars_we_set   = Hashtbl.create 101;
  }

let shellenv_of_env env =
  Hashtbl_.to_list env.internal_vars @
  Hashtbl_.to_list env.vars
