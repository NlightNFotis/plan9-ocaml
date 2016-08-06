(* Copyright 2016 Yoann Padioleau, see copyright.txt *)
open Common

module J = Job
module G = Graph
module R = Rules
module E = Env

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Globals *)
(*****************************************************************************)

let running = Hashtbl.create 101
let nrunning = ref 0

(* todo: use environemt to set it *)
let nproclimit = ref 2

let jobs = Queue.create ()

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* !modify by side effect job.env! *)
let adjust_env job =
  let env = job.J.env in

  (* less: should be all_target *)
  Hashtbl.replace env.E.internal_vars "target" job.J.all_targets;
  (* less: newprereqs *)
  Hashtbl.replace env.E.internal_vars "prereq" job.J.all_prereqs;
  job.J.rule.Rules.stem |> Common.if_some (fun s ->
    Hashtbl.replace env.E.internal_vars "stem" [s];
  );

  env

let shprint env s =
  let s = 
    Str.global_substitute (Str.regexp "\\$\\([a-zA-Z][a-zA-Z0-9_]*\\)")
      (fun _wholestr ->
        let var = Str.matched_group 1 s in
        if Hashtbl.mem env.E.internal_vars var
        then Hashtbl.find env.E.internal_vars var |> String.concat " "
        else 
          if Hashtbl.mem env.E.vars_we_set var
          then Hashtbl.find env.E.vars var |> String.concat " "
          else Str.matched_string s
      ) s
  in
  print_string (s ^ "\n")

(*****************************************************************************)
(* Main algorithms *)
(*****************************************************************************)

let sched () =
  try 
    let job = Queue.take jobs in
    let recipe = 
      match job.J.rule.R.recipe2 with 
      | Some (Ast.R x) -> x
      | None -> raise (Impossible "job without a recipe")
    in
    let env = adjust_env job in
    
    (* less: unless Quiet *)
    recipe |> List.iter (fun s -> shprint env s);

    if !Flags.dry_mode 
    then job.J.target_nodes |> List.iter (fun node ->
      node.G.time <- Some (Unix.time ());
      node.G.state <- G.Made;
    )
    else
      let flags = ["-e"] in
      let shellenv = Env.shellenv_of_env env in
      let pid = Shell.execsh shellenv flags recipe in
      Hashtbl.add running pid job;
      incr nrunning
    
  with Queue.Empty ->
    raise (Impossible "no jobs to schedule")


(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

let run job =
  Queue.add job jobs;
  if !nrunning < !nproclimit
  then sched ()


let waitup () =
  let (pid, ret) = Unix.wait () in
  let job = 
    try Hashtbl.find running pid
    with Not_found ->
      raise 
        (Impossible (spf "wait returned unexpected process with pid %d" pid))
  in
  decr nrunning;
  Hashtbl.remove running pid;

  match ret with
  | Unix.WEXITED 0 ->
      job.J.target_nodes |> List.iter (fun node ->
        G.update node
      );
      (* same code than in run *)
      if !nrunning < !nproclimit
      then sched ()
  | Unix.WEXITED n ->
      failwith (spf "error in child process, exit status = %d" n)
  | Unix.WSIGNALED n | Unix.WSTOPPED n ->
      failwith (spf "child process killed/stopped by signal = %d" n)
