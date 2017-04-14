open Common

open Syscall

(* todo: uniform return value?? catch errors?
*)
let dispatch syscall =
  match syscall with
  | Nop -> Sysnop.syscall_nop ()

  | Brk x -> Sysbrk.syscall_brk x

  | Errstr -> Syserrstr.syscall_errstr ()

  | _ -> raise Todo
