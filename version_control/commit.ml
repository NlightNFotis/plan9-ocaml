(*
 * Copyright (c) 2013-2017 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* 
 * 
 * Most of the code below derives from: https://github.com/mirage/ocaml-git
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type t = {
  tree     : Tree.hash;
  (* first commit has no parent, and merge commits have 2 parents *)
  parents  : hash list;
  (* note that User.t contains a time *)
  author   : User.t;
  committer: User.t;

  (* less: encoding, gpgsig, mergetag, extra *)

  message  : string;
}
and hash = Sha1.t

(*****************************************************************************)
(* IO *)
(*****************************************************************************)

let read ch =
  let tree = 
    IO_.read_key_space_value_newline ch "tree" Hexsha.read in
  (* todo: read "parent" or "author", because first commit has no parent *)
  let parents, author = 
    let rec loop parents =
      let str = IO_.read_string_and_stop_char ch ' ' in
      match str with
      | "parent" -> 
        let v = Hexsha.read ch in
        let c = IO.read ch in
        if c <> '\n'
        then failwith "Commit.read: missing newline after parent";
        loop (v::parents)
      | "author" ->
        let v = User.read ch in
        let c = IO.read ch in
        if c <> '\n'
        then failwith "Commit.read: missing newline after author";
        List.rev parents, v
      | _ -> failwith (spf "Commit.read: was expecting parent or author not %s"
                         str)
    in
    loop []
  in
  let committer = 
    IO_.read_key_space_value_newline ch "committer" User.read in
  let c = IO.read ch in
  if c <> '\n'
  then failwith "Commit.read: missing newline before message";
  let msg = IO.read_all ch in
  { tree = Hexsha.to_sha tree; 
    parents = parents |> List.map Hexsha.to_sha; 
    author = author; committer = committer;
    message = msg;
  }

let write commit ch =
  IO.nwrite ch "tree ";
  Hexsha.write ch (Hexsha.of_sha commit.tree);
  IO.write ch '\n';
  commit.parents |> List.iter (fun parent ->
    IO.nwrite ch "parent ";
    Hexsha.write ch (Hexsha.of_sha parent);
    IO.write ch '\n';
  );
  IO.nwrite ch "author ";
  User.write ch commit.author;
  IO.write ch '\n';
  IO.nwrite ch "committer ";
  User.write ch commit.committer;
  IO.write ch '\n';

  IO.write ch '\n';
  IO.nwrite ch commit.message

(*****************************************************************************)
(* Show *)
(*****************************************************************************)

let show x =
  pr (spf "Author: %s <%s>" x.author.User.name x.author.User.email);
  (* less: date of author or committer? *)
  let date = x.author.User.date in
  pr (spf "Date:   %s" (User.string_of_date date));
  pr "";
  pr ("    " ^ x.message)
  (* showing diff done in caller in Cmd_show.show *)        
