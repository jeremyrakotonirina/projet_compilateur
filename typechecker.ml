open Mgoast

exception Error of Mgoast.location * string

(* fonctions à appeler en cas d'erreur*)
let error loc s = raise (Error (loc,s))

let type_error loc ty_actual ty_expected = 
  error loc (Printf.sprintf "expected %s, got %s"
           (typ_to_string ty_expected) (typ_to_string ty_actual))

module Env = Map.Make(String) (*les clés sont des string*)

(* 3 environnements pour stocker
     les variables avec leur type,
     les fonctions avec leur signature
     les structures avec leurs champs
*)
    
type tenv = typ Env.t 
type fenv = (typ list) * (typ list) Env.t (*valeur sont des liste des types de paramètres * liste des types de retour des fonctions*)
type senv = (ident * typ) list Env.t

let dummy = "_"
let dummy_loc = (Lexing.dummy_pos, Lexing.dummy_pos) (*utilisé à la fin du fichier pour position fictif*)

(* Ajout d'une déclaration de variables à un environnement tenv. Ignore la variable '_'. *)
let add_env l tenv =
  List.fold_left (fun env (x, t) -> 
    if x.id = dummy then env 
    else Env.add x.id t env
  ) tenv l

(* Vérifie l'unicité des noms dans une liste de (ident * typ)  *)
let check_uniqueness l =
  let rec aux seen ll= 
    match ll with
    | [] -> ()
    | (id, _) :: rest ->
        if id.id = dummy then aux seen rest (* '_' peut être utilisé plusieurs fois *)
        else if List.mem id.id seen then
          error id.loc (Printf.sprintf "duplicate identifier: %s" id.id)
        else
          aux (id.id :: seen) rest
  in
  aux [] l
  
let prog (fmt,ld) =
  (* collecte les noms des fonctions et des structures sans les vérifier *)
  let (fenv,senv) =
    List.fold_left
      (fun (fenv,senv) d ->
         match d with 
        | Struct(s) -> 
            if Env.mem s.sname.id senv then 
              error s.sname.loc (Printf.sprintf "duplicate structure def: %s" s.sname.id);
            (fenv, Env.add s.sname.id s.fields senv)
        | Fun(f) ->
            if Env.mem f.fname.id fenv then
              error f.fname.loc (Printf.sprintf "duplicate function def: %s" f.fname.id);
            
            check_uniqueness f.params;(* Vérification unicité des paramètres *)

            let param_types = List.map snd f.params in
            let return_types = f.return in

            (Env.add f.fname.id (param_types, return_types) fenv, senv))
      (Env.empty, Env.empty) ld
  in

  (* Vérifie si un type est bien formé *)
  let check_typ loc t =
    match t with
    | TInt | TBool | TString -> ()
    | TStruct s_name ->
        if Env.mem s_name senv then ()
        else error loc (Printf.sprintf "unknown structure type: *%s" s_name)
  in

  (* Vérification d'une liste de champs de structure *)
  let check_fields lf = 
    if lf <> [] then check_uniqueness lf; 
    List.iter (fun (id, t) -> check_typ id.loc t) lf 
  in

  let rec check_expr e typ tenv = (* Vérifie si le type de l'expression correspond au type attendu*)
    if e.edesc = Nil then  
        match typ with
      | TStruct _ -> () (* Nil peut être n'importe quel *S  *)
      | _ -> type_error e.eloc (TStruct "nil") typ
    else 
      let typ_e = type_expr e tenv in
      if typ_e <> typ then type_error e.eloc typ_e typ

  and type_expr e tenv = match e.edesc with (* Détermine le type de l'expression et retourne le type. *)
    | Int _  -> TInt
    | String _ -> TString 
    | Bool _   -> TBool
    | Unop (Not, e') -> 
        check_expr e' TBool tenv ; 
        TBool
    | Unop (Opp, e') -> 
        check_expr e' TInt tenv ; 
        TInt 
    | Binop ((Add | Sub | Mul | Div | Rem), e1, e2) ->
        check_expr e1 TInt tenv  ;
        check_expr e2 TInt tenv  ;
        TInt 
    | Binop ((Lt | Le | Gt | Ge), e1, e2) ->
        check_expr e1 TInt tenv  ;
        check_expr e2 TInt tenv  ;
        TBool
    | Binop ((And | Or), e1, e2) ->
        check_expr e1 TBool tenv  ;
        check_expr e2 TBool tenv  ;
        TBool 
    | Binop ((Eq | Neq), e1, e2) ->
        let t1 = type_expr e1 tenv   in
        let t2 = type_expr e2 tenv   in
        
        if t1 <> t2 then error e.eloc "operands of == or != must have the same type";
        
        (* Interdiction de comparer nil à lui-même *)
        if e1.edesc = Nil && e2.edesc = Nil then error e.eloc "cannot compare nil to itself";
        
        TBool
    | Var id   -> (try Env.find id.id tenv with Not_found -> error id.loc (Printf.sprintf "error variable: %s" id.id))
    | Nil      -> TStruct "nil"
    | New s_name -> 
      if Env.mem s_name senv then TStruct s_name (* Crée un pointeur sur une nouvelle structure *)
      else error e.eloc (Printf.sprintf "cannot create new on unknown structure %s" s_name)
    
    | Dot (e', id) -> (*e' est la structure et ident le champ*)
      let t_ptr = type_expr e' tenv in
      (match t_ptr with
       | TStruct s ->
             if e.edesc = Nil then error e.eloc "nil access";
             let fields = Env.find s senv in
             (try 
                let (_, t) = List.find (fun (f_id, _) -> f_id.id = id.id) fields in
                t
              with Not_found -> error id.loc "unknown field")
         | t -> type_error e.eloc t (TStruct "pointer"))

    | Call (id, args) ->
        let ret = type_call id.loc id.id args tenv in
        (match ret with [t] -> t | _ -> error id.loc "call must return exactly one value")
    
    | Print args ->
        List.iter (fun e -> 
          match e.edesc with 
          | Call(id, args) -> ignore(type_call id.loc id.id args tenv) 
          | _ -> ignore(type_expr e tenv)
        ) args;
        TStruct "unit"
    
    (* Fonction auxiliaire pour gérer les appels de fonctions,elle retourne la liste des types de retour *)
    and type_call loc fname args tenv =
    try
      let (param_types, return_types) = Env.find fname fenv in
      if List.length param_types <> List.length args then
        error loc "wrong number of arguments";
      
      (* On vérifie chaque argument contre le type attendu *)
      List.iter2 (fun e t -> check_expr e t tenv) args param_types;
      
      return_types
    with Not_found -> error loc (Printf.sprintf "error function: %s" fname)
  in
  

  let check_lvalue e tenv = (*vérifie si c'est valeur gauche*)
    match e.edesc with
    | Var _ | Dot (_, _) -> type_expr e tenv 
    | _ -> error e.eloc "expected lvalue " 
  in

  let rec check_instr i ret tenv = 
    match i.idesc with
    | Inc e | Dec e -> 
      let t = check_lvalue e tenv  in
      if t <> TInt then type_error e.eloc t TInt;
      tenv
  
    | Block s -> 
      ignore (check_seq s ret tenv); 
      tenv

    | If (e, b1, b2) ->
      check_expr e TBool tenv ; 
      ignore (check_seq b1 ret tenv) ;
      ignore (check_seq b2 ret tenv) ;
      tenv

    | For (e, b) ->
      check_expr e TBool tenv ; 
      ignore (check_seq b ret tenv) ;
      tenv

    | Vars (ids, t_opt, init_seq) ->
        check_uniqueness  (List.map (fun id -> (id, TInt)) ids);
        
        let final_t = match t_opt with
          | Some t -> check_typ i.iloc t; t
          | None -> (
              match init_seq with
              | [ instr ] -> ( 
                  match instr.idesc with
                  | Set (_, exps) -> 
                      if exps = [] then error i.iloc "init required";
                      if List.exists (fun e -> e.edesc = Nil) exps then error i.iloc "nil needs type";
                      
                      (* Gestion de l'initialisation par appel de fonction *)
                      (match exps with
                       | [{edesc=Call(id, args);_}] -> 
                           let ret_types = type_call id.loc id.id args tenv in
                           (match ret_types with t::_ -> t | [] -> error id.loc "void func")
                       | _ -> 
                           if List.length exps >= 1 then type_expr (List.hd exps) tenv else TInt)
                  
                  
                  | _ -> error i.iloc "initialization must be an assignment"
                )
              | _ -> error i.iloc "invalid sequence"
            )
        in
        
        let new_vars = List.map (fun id -> (id, final_t)) ids in
        let tenv_ext = add_env new_vars tenv in
        ignore (check_seq init_seq ret tenv_ext);
        tenv_ext

    | Set (gauche, droite) ->
        let t_left = List.map (fun e -> check_lvalue e tenv) gauche in
        let t_right = match droite with
          | [{edesc=Call(id, args);_}] -> type_call id.loc id.id args tenv (*extrait ceux dont l'expression est Call(id,args)*)
          | _ -> List.map (fun e -> type_expr e tenv) droite
        in
        if List.length t_left <> List.length t_right then error i.iloc "error mismatch";
        List.iter2 (fun tl tr -> if tl <> tr then type_error i.iloc tr tl) t_left t_right;
        tenv

    | Return exps ->
        let t_rets = match exps with
          | [{edesc=Call(id, args);_}] -> type_call id.loc id.id args tenv
          | _ -> List.map (fun e -> type_expr e tenv) exps
        in
        if t_rets <> ret then error i.iloc "return type mismatch";
        tenv

    | Expr e -> ignore (type_expr e tenv);
        tenv

  and check_seq s ret tenv =
    List.fold_left (fun env i -> check_instr i ret env) tenv s
  in
  

  let check_function f = 
    let (param_types, ret_types) = Env.find f.fname.id fenv in
    let tenv_initial = add_env f.params Env.empty in
    
    ignore(check_seq f.body ret_types tenv_initial);

    if f.fname.id = "main" then (
      if param_types <> [] || ret_types <> [] then
        error f.fname.loc "function main must have no parameters and no return type"
    )
  in


  (* Vérification des types dans les  structures et signatures *)
  Env.iter (fun _ fields -> check_fields fields) senv;
  Env.iter (fun _ (params, rets) -> 
    List.iter (check_typ dummy_loc) params;
    List.iter (check_typ dummy_loc) rets
  ) fenv;

  (* Vérification des corps de fonction *)
  List.iter (fun d -> match d with Fun f -> check_function f | _ -> ()) ld;

  (* Vérification: Import fmt *)
  let fmt_used_in_code = 
    let rec used_in_instr i = match i.idesc with
      | Expr {edesc=Print _; _} -> true  (* Warning 9: ajout de ; _ *)
      | Block s -> List.exists used_in_instr s
      | For (_, s) -> List.exists used_in_instr s
      | If (_, s1, s2) -> List.exists used_in_instr s1 || List.exists used_in_instr s2
      | Vars (_, _, s) -> List.exists used_in_instr s
      | _ -> false 
    in
    List.exists (function Fun f -> List.exists used_in_instr f.body | _ -> false) ld
  in
  
  if fmt <> fmt_used_in_code then
    error dummy_loc "file must import \"fmt\" if and only if fmt.Print is used";
  (fmt, ld)
