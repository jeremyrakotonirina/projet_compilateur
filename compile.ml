open Mgoast
open Mips

type env = {                                     (*type environnement pour donner la position*)
  locals : (string * int) list;                  (*des variables locales*)
  next_offset : int;                             (*le prochain decalage*)
  structs : (string * (string * int) list) list; (*des structures*)
  strings : (string * string) list;              (*(label, chaine) pour les chaines de caracteres*)
  next_str : int;                                (*compteur pour des labels uniques*)
}

let empty_env = {
  locals = [];
  next_offset = 0;
  structs = [];
  strings = [];
  next_str = 0;
}

let lookup_local env id =
  try List.assoc id env.locals
  with Not_found -> failwith ("Unknown local variable: " ^ id)

let add_local env name =
  let offset = env.next_offset - 4 in
  { env with 
    locals = (name, offset) :: env.locals; 
    next_offset = offset 
  }, offset

let register_struct env (sd : struct_def) =
  let _, offsets =
    List.fold_left
      (fun (ofs, acc) (field_id, _) ->
         let acc' = (field_id.id, ofs) :: acc in
         (ofs + 4, acc'))
      (0, []) sd.fields
  in
  { env with structs = (sd.sname.id, List.rev offsets) :: env.structs }

let lookup_struct env name =
  try List.assoc name env.structs
  with Not_found -> failwith (Printf.sprintf "unknown struct: %s" name)

let alloc_string env s =
  let lbl = "_str_" ^ string_of_int env.next_str in
  let env' = {
    env with
    next_str = env.next_str + 1;
    strings = (lbl, s) :: env.strings
  } in
  (lbl, env')

let emit_strings env =
  List.fold_right (fun (lbl, s) acc -> label lbl @@ asciiz s @@ acc) env.strings nop

let new_label =
  let cpt = ref (-1) in
  fun () -> incr cpt; Printf.sprintf "_label_%i" !cpt

let find_field_offset env field_name = (* Cherche l'offset d'un champ dans toutes les structures connues *)
  let rec search = function
    | [] -> failwith ("Field pas trouvé: " ^ field_name)
    | (_, fields) :: ll ->
        try List.assoc field_name fields
        with Not_found -> search ll
  in
  search env.structs

(* le résultat de l'expression est dans le registre $t0,
   la pile est utilisée pour les valeurs intermédiaires *)
let rec tr_expr env e = 
  match e.edesc with
  | Int(n)  -> (li t0 (Int64.to_int n), env)   (* on supposera que les constantes entières
                                           sont représentables sur 32 bits *)
  | String(s) -> let label, env' = alloc_string env s in (* allocation des chaînes dans la zone de données statiques *)
                 (la t0 label, env')

  | Var(id) -> let offset = lookup_local env id.id in
               (lw t0 offset fp, env)

  | Bool b -> (li t0 (if b then 1 else 0), env)

  | Nil -> (li t0 0, env)

  | Binop(bop, e1, e2) ->
    let op = match bop with
      | Add -> add t0 t0 t1
      | Sub -> sub t0 t0 t1
      | Mul -> mul t0 t0 t1
      | Div -> div t0 t1 @@ mflo t0 
      | Rem -> div t0 t1 @@ mfhi t0 
      
      | Eq  -> seq t0 t0 t1
      | Neq -> sne t0 t0 t1
      | Lt  -> slt t0 t0 t1        
      | Le  -> slt t0 t1 t0 @@ xori t0 t0 1  (* on raisonne par le cas contraire *)
      | Gt  -> slt t0 t1 t0        
      | Ge  -> slt t0 t0 t1 @@ xori t0 t0 1 
      
      | And -> and_ t0 t0 t1
      | Or  -> or_ t0 t0 t1
    in
    let code2, env1 = tr_expr env e2 in
    let code_push = push t0 in
    let code1, env2 = tr_expr env1 e1 in
    let code_pop = pop t1 in
    ( code2
      @@ code_push
      @@ code1
      @@ code_pop
      @@ op,
      env2 
    )

  | Call(f, args) ->
    let code_args, env1 = tr_args env args in
    ( code_args 
      @@ jal f.id 
      @@ addi sp sp (4 * List.length args) 
      @@ nop, (*convention de ocaml pour eviter une execution d'instruction non voulu*)
      env1 )
    
   | Unop (Opp, e1) -> let code1, env1 = tr_expr env e1 in
                       ( code1 @@ (neg t0 t0), env1 )
  
   | Unop (Not, e1) -> let code1, env1 = tr_expr env e1 in
                       ( code1 @@ (xori t0 t0 1), env1 )
   | Print(args) -> tr_print_args env args
   | New(struct_name) ->
      let fields_offsets = lookup_struct env struct_name in
      let size = 4 * List.length fields_offsets in
      ( li a0 size
        @@ li v0 9
        @@ syscall
        @@ move t0 v0, 
        env )

   | Dot (e, field_id) ->
      let code_e, env' = tr_expr env e in
      let offset = find_field_offset env' field_id.id in
      ( code_e
        @@ lw t0 offset t0, 
        env' )

  and tr_args env args= 
  match args with
  | [] -> (nop, env)
  | e :: rest ->
      let code_e, env1 = tr_expr env e in
      let code_push = push t0 in
      let code_rest, env2 = tr_args env1 rest in
      (code_e @@ code_push @@ code_rest, env2)

and tr_print_args env args = 
  match args with
  | [] -> (nop, env)
  | e :: rest ->
      let code_e, env1 = tr_expr env e in
      let code_print = jal "print_int" in
      let code_rest, env2 = tr_print_args env1 rest in
      ( code_e @@ code_print @@ code_rest, env2 )

let rec tr_seq env = function
  | [] -> (nop, env)
  | i :: s ->
      let code_i, env1 = tr_instr env i in
      let code_s, env2 = tr_seq env1 s in
      (code_i @@ code_s, env2)

and tr_instr env i = 
  match i.idesc with 
  | If(c, s1, s2) ->
      let then_label = new_label () in
      let end_label = new_label () in
      let code_c, env1 = tr_expr env c in    (*condition*)
      let code_s2, env2 =  tr_seq env1 s2 in (*else*)
      let code_s1, env3 = tr_seq env2 s1 in  (*then*)
      ( code_c
        @@ bnez t0 then_label
        @@ code_s2
        @@ b end_label
        @@ label then_label
        @@ code_s1
        @@ label end_label,
        env3 )

  | For(c, s) ->
    let test_label = new_label() in
    let code_label = new_label() in
    let code_s, env1 =  tr_seq env s in  (*suite d'instructions*)
    let code_c, env2 = tr_expr env1 c in    (*condition*)
    ( b test_label
    @@ label code_label
    @@ code_s
    @@ label test_label
    @@ code_c
    @@ bnez t0 code_label,
    env2 )
    
  | Vars (ids, _, body) ->
      let env_vars, alloc_code =
        List.fold_left
          (fun (env_acc, code_acc) id ->
             let env_next, _ = add_local env_acc id.id in
             (env_next, code_acc @@ addi sp sp (-4) @@ sw zero 0(sp)))
          (env, nop) ids
      in
      let code_body, env_body = tr_seq env_vars body in
      ( alloc_code @@ code_body,
        env_body )

  | Set ([lhs], [rhs]) ->
       begin match lhs.edesc with 
      | Var id ->
          let ofs = lookup_local env id.id in
          let code_rhs, env1 = tr_expr env rhs in
          (code_rhs @@ sw t0 ofs fp, env1)
      | Dot (e, field) ->
          let code_e, env1 = tr_expr env e in 
          let code_rhs, env2 = tr_expr env1 rhs in 
          let offset = find_field_offset env field.id in
           (code_e 
            @@ push t0 
            @@ code_rhs 
            @@ pop t1 
            @@ sw t0 offset t1, 
            env2)
      | _ -> failwith "Set: required l value"
      end

  | Block s ->
    let code1, env1 = tr_seq env s in  
    let env_out = { 
      env with 
      strings = env1.strings;
      next_str = env1.next_str;
      locals = env.locals;
      next_offset = env.next_offset;
    } in  
    (code1, env_out) 
  
  | Expr e ->
      let code, env1 = tr_expr env e in
      (code, env1)

  | Return exps ->
      let code, env1 = match exps with
        | [e] -> tr_expr env e
        | [] -> (nop, env)
        | _ -> failwith "multiple returns not supported"
      in
      (code @@ move v0 t0 @@ move sp fp @@ lw ra (-4)(sp) @@ lw fp 0(sp) @@ jr ra, env1)

  | Inc e ->
      (match e.edesc with
       | Var id ->
           let ofs = lookup_local env id.id in
           ( lw t0 ofs fp       
             @@ addi t0 t0 1    
             @@ sw t0 ofs fp,   
             env )

       | Dot (exp, field) ->
           let code_exp, env' = tr_expr env exp in 
           let offset = find_field_offset env' field.id in
           ( code_exp
             @@ lw t1 offset t0 
             @@ addi t1 t1 1   
             @@ sw t1 offset t0,
             env' )

       | _ -> failwith "Inc: required l value")

  | Dec e ->
      (match e.edesc with
       | Var id ->
           let ofs = lookup_local env id.id in
           ( lw t0 ofs fp
             @@ addi t0 t0 (-1) 
             @@ sw t0 ofs fp,
             env )

       | Dot (exp, field) ->
           let code_exp, env' = tr_expr env exp in
           let offset = find_field_offset env' field.id in
           ( code_exp
             @@ lw t1 offset t0
             @@ addi t1 t1 (-1)
             @@ sw t1 offset t0,
             env' )

       | _ -> failwith "Dec: required l value")

  | _ ->
      failwith "instruction not supported"


let tr_fun env df =
  let prologue = 
    push fp        
    @@ push ra    
    @@ move fp sp 
  in

  let local_env = { env with locals = []; next_offset = 0 } in
  
  let code_body, env_after_body = tr_seq local_env df.body in

  let epilogue =
    move sp fp      
    @@ lw ra (-4)(sp) 
    @@ lw fp 0(sp)    
    @@ jr ra 
  in

  let fin_fonction = (*pour gérer le cas de main*)
    if df.fname.id = "main" then
      li v0 10 @@ syscall 
      
    else
      epilogue
  in
  
  (* On assemble le tout *)
  let code = label df.fname.id @@ prologue @@ code_body @@ fin_fonction in
  let env1 =
    { env with
      strings = env_after_body.strings;
      next_str = env_after_body.next_str;
    }
  in
  (code, env1)

let rec tr_ldecl env = function
  | [] -> (nop, env)
  | Struct sd :: rest ->
      let env' = register_struct env sd in
      tr_ldecl env' rest
  | Fun df :: rest ->
      let code_f, env1 = tr_fun env df in
      let code_rest, env2 = tr_ldecl env1 rest in
      (code_f @@ code_rest, env2)


let runtime_print =
  label "print_int"
  @@ move a0 t0          
  @@ li v0 1
  @@ syscall
  @@ jr ra
  @@ nop

  @@ label "print_bool"
  @@ bnez t0 "print_bool_true"
  @@ la a0 "_print_bool_false" (* on a rajouté un _ au début pour que ça corresponde avec  runtime_strings car on avait un avertissemnet*)
  @@ b "print_bool_end"
  @@ label "print_bool_true"
  @@ la a0 "_print_bool_true"
  @@ label "print_bool_end"
  @@ li v0 4
  @@ syscall
  @@ jr ra
  @@ nop

  @@ label "print_string"
  @@ move a0 t0
  @@ li v0 4
  @@ syscall
  @@ jr ra
  @@ nop

  @@ label "print_newline"
  @@ la a0 "_print_newline"
  @@ li v0 4
  @@ syscall
  @@ jr ra
  @@ nop

let runtime_strings =
  label "_print_bool_true" @@ asciiz "true"
  @@ label "_print_bool_false" @@ asciiz "false"
  @@ label "_print_newline" @@ asciiz "\n"

let tr_prog (_, decls) =
  let code_text, env_final = tr_ldecl empty_env decls in
  { 
    text = code_text @@ runtime_print; 
    data = emit_strings env_final @@ runtime_strings; 
  }


