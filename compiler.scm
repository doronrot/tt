(load "compiler_hw3.scm")

;;;none-clear;;;
;starg (inlib/char&io/ in some files)
;addr(0) (in lib/system/malloc)


(define count 0)

(define code-gen
	(lambda (pe major)
		(cond 
			 ;void
			  ((equal? pe `(const ,(void)))
				(string-append
					"MOV(R0, IMM(SOB_VOID));\n"
					; "PUSH(R0);\n"
					; "CALL(WRITE_SOB_VOID);\n"
					; "POP(R0);\n"
					))
			  ;list
			   ((equal? pe `(const ()))
			   	 (string-append
				    "MOV(R0, IMM(SOB_NIL));\n"
	 				; "PUSH(R0);\n"
	 				; "CALL(WRITE_SOB_NIL);\n"
	 				; "POP(R0);\n"
	 				))
			   ;#f
			   ((equal? pe `(const #f))
			   	 (string-append
				    "MOV(R0, IMM(SOB_FALSE));\n"
	 				; "PUSH(R0);\n"
	 				; "CALL(WRITE_SOB_BOOL);\n"
	 				; "POP(R0);\n"
	 				))
			   ;#t
			   ((equal? pe `(const #t)) 
			  	 (string-append
				    "MOV(R0, IMM(SOB_TRUE));\n"
	 				; "PUSH(R0);\n"
	 				; "CALL(WRITE_SOB_BOOL);\n"
	 				; "POP(R0);\n"
	 				))
			   ;if
			  	((and (pair? pe) 
			  	    (equal? (car pe) 'if3))
			  	 (set! count (+ count 1))
			  	 (let ((test (cadr pe))
			  	 	   (dit (caddr pe))
			  	 	   (dif (cadddr pe))
			  	 	   (count_str (number->string count)))
			  	 	(string-append (code-gen test major)
			  	 				    "CMP (R0, IMM(SOB_FALSE));\n"
			  	 				    "JUMP_EQ (L_if3_else_"count_str");\n"
			  	 				    (code-gen dit major)
			  	 				    "JUMP (L_if3_exit_"count_str");\n"
			  	 				    "L_if3_else_"count_str":\n"
			  	 				    (code-gen dif major)
			  	 				    "L_if3_exit_"count_str":\n")))
			  ;seq
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'seq))
			   (let ((seq_body (cadr pe)))
			   	 (letrec ((run (lambda (lst)
			   	 					(if (null? lst)
			   	 						""
			   	 						(string-append (code-gen (car lst) major)
			   	 									   (run (cdr lst)))))))
			   	 	(run seq_body))))
			  	;or
			  ((and (pair? pe)
			  		(equal? (car pe) 'or))
			  	(set! count (+ count 1))
			  	(let ((or_exps (cadr pe))
			  		  (count_str (number->string count)))
			  		(letrec ((run (lambda (lst)
			  						 (if (equal? (length lst) 1)
			  						 	 (string-append (code-gen (car lst) major)
			  						 	 				"L_or_exit_"count_str":\n")
			  						 	 (string-append (code-gen (car lst) major)
			  						 	 				"CMP(R0, IMM(SOB_FALSE));\n"
			  						 	 				"JUMP_NE(L_or_exit_"count_str");\n"
			  						 	 				(run (cdr lst)))))))
			  			 (run or_exps))))
			  ;applic
			  ((and (pair? pe) 
			  		(equal? (car pe) 'applic))
			  	(set! count (+ count 1))
			  	(let* ((proc (cadr pe))
			  		   (args (caddr pe))
			  		   (args_count (length args))
			  		   (args_count_str (number->string args_count))
			  		   (count_str (number->string count)))
			  		(letrec ((run (lambda (lst) 
			  						 (if (null? lst)
			  						 	 (string-append 
			  						 	   "PUSH ("args_count_str");\n"
  						 				   (code-gen proc major)
  						 				   "CMP (INDD(R0, 0),IMM(T_CLOSURE));\n"
  						 				   "JUMP_NE (L_error_cannot_apply_non_clos_"count_str");\n"
  						 				   "PUSH (INDD(R0,1));\n"
  						 				   "MOV (R4, INDD(R0,2));\n"
  						 				   "CALLA (R4);\n"
  						 				   "DROP (1);\n"
  						 				   "POP (R1);\n"
  						 				   "DROP(R1);\n"
  						 				   "JUMP (L_applic_exit_"count_str");\n"
  						 				   "L_error_cannot_apply_non_clos_"count_str":\n"
  						 				   "L_applic_exit_"count_str":\n")
			  						 	 (string-append 
			  						 	   (code-gen (car lst) major)
  						 				   "PUSH (R0);\n"
  						 				   (run (cdr lst)))))))
			  			(run (reverse args)))))
			  ;lambda-simple
			  ((and (pair? pe) 
			  		(equal? (car pe) 'lambda-simple))
			  	(set! count (+ count 1))
			  	(let* (
			  		   (params (cadr pe))
			  		   (num_params (length params))
			  		   (num_params_str (number->string num_params))
			  		   (body (caddr pe))
			  		   (count_str (number->string count))
				  	   (major_str (number->string major)))
			  	  (string-append 
					"MOV (R1,FPARG(0));\n"	;env
					"PUSH (IMM(1+"major_str"));\n"
					"CALL(MALLOC);\n"
					"DROP(1);\n"
					"MOV (R2, R0);\n"
					(letrec ((shallow_copy 
								(lambda (i j)
								   (let ((i_str (number->string i))
								   		 (j_str (number->string j)))
									   (if (>= i major)
									   	   ""
									   	   (string-append 
									   	   	  "MOV (R4, INDD(R1,"i_str"));\n"
									   	   	  "MOV (INDD(R2,"j_str"), R4);\n"
									   	   	  (shallow_copy (+ i 1) (+ j 1))))))))
					   	(shallow_copy 0 1))
					"MOV(R3,FPARG(1));\n"	;number of argumets
					"PUSH(R3);\n"
					"CALL(MALLOC);\n"
					"DROP(1);\n"
					"MOV (INDD(R2,0), R0);\n"
					; (letrec ((copy_stack_params 
					; 			(lambda (i j)
					; 			   (let ((i_str (number->string i))
					; 			   		 (j_str (number->string j)))
					; 				   (if (>= i num_params)
					; 				   	   (number->string num_params)
					; 				   	   (string-append 
					; 				   	   	  "MOV (R4, (INDD(R2,0)));\n"
					; 				   	   	  "MOV (R5, FPARG("j_str"));\n"
					; 				   	   	  "MOV (INDD(R4, "i_str"), R5);\n"
					; 				   	   	  (copy_stack_params (+ i 1) (+ j 1))))))))
					;    	(copy_stack_params 0 2))
					"MOV (R6, 0);\n" ;i
					"MOV (R7, 2);\n" ;j
					"L_clos_loop_"count_str":\n"
					"CMP (R6, R3);\n"
					"JUMP_GE (L_clos_loop_end_"count_str");\n"
					"MOV (R4, (INDD(R2,0)));\n"
					"MOV (R5, FPARG(R7));\n"
					"MOV (INDD(R4, R6), R5);\n"
					"ADD (R6, IMM(1));\n"
					"ADD (R7, IMM(1));\n"
					"JUMP (L_clos_loop_"count_str");\n"
					"L_clos_loop_end_"count_str":\n"

					"PUSH (IMM(3));\n"
					"CALL(MALLOC);\n"
					"DROP(1);\n"
					"MOV (INDD(R0,0),IMM(T_CLOSURE));\n"
					"MOV (INDD(R0,1),R2);\n"	;ext. env
					
					"MOV (INDD(R0,2),LABEL(L_clos_body_"count_str"));\n"
					"JUMP (L_clos_exit_"count_str");\n"
					
					"L_clos_body_"count_str":\n"
					"PUSH (FP);\n"
					"MOV (FP,SP);\n"

					"CMP (FPARG(1),IMM("num_params_str"));\n"
					"JUMP_NE (L_error_lambda_args_count_"count_str");\n"
					(code-gen body (+ major 1))
					"JUMP (L_clos_ok_"count_str");\n"
					"L_error_lambda_args_count_"count_str":\n"
					"L_clos_ok_"count_str":\n"
					"POP (FP);\n"
					"RETURN;\n"		;return to caller
					"L_clos_exit_"count_str":\n"
					)))
			  ;pvar
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'pvar))
			   (let* ((minor (caddr pe)) 
			   		  (minor_str (number->string minor)))
			   	(string-append
			   		"MOV (R0, FPARG(2+"minor_str"));\n" ;the minor's argument
			   		)))			  
			  ;bvar
			  ((and (pair? pe) 
			  		(equal? (car pe) 'bvar))
			   (let* ((major (caddr pe))
			   		  (minor (cadddr pe))
			   		  (major_str (number->string major))
			   		  (minor_str (number->string minor)))
			   	(string-append
			   		"MOV (R0, FPARG(0));\n" ;env
			   		"MOV (R0, INDD(R0,"major_str"));\n"	   		
			   		"MOV (R0, INDD(R0,"minor_str"));\n")))
			  ;set pvar
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'set)
			  	    (equal? (caadr pe) 'pvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (caddr complete_var))
			   		  (value (caddr pe)) 
			   		  (minor_str (number->string minor)))
			   	(string-append
			   		(code-gen value major)
			   		"MOV (FPARG(2+"minor_str"), R0);\n"
			   		"MOV (R0, IMM(T_VOID));\n" ;IMPORTANT TODO!! - AFTER CONST TABLE CHANGE TO SOB_VOID
			   		)))
			  ;set bvar
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'set)
			  	    (equal? (caadr pe) 'bvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (cadddr complete_var))
			   		  (major (caddr complete_var))
			   		  (value (caddr pe)) 
			   		  (minor_str (number->string minor))
			   		  (major_str (number->string major)))
			   	(string-append
			   		(code-gen value major)
			   		"MOV (R1, FPARG(0));\n" ;env
			   		"MOV (R1, INDD(R1,"major_str"));\n"	   		
			   		"MOV (INDD(R1,"minor_str"), R0);\n"
			   		"MOV (R0, IMM(T_VOID));\n" ;IMPORTANT TODO!! - AFTER CONST TABLE CHANGE TO SOB_VOID
			   		)))
			  ;box-get pvar ;TODO - CHECK!! AFTER HANDLE WITH SEQ
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'box-get)
			  	    (equal? (caadr pe) 'pvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (caddr complete_var))
			   		  (minor_str (number->string minor)))
			   	(string-append
			   		"MOV (R0, FPARG(2+"minor_str"));\n"
			   		"MOV (R0, IND(R0));\n"
			   		)))
			  ;box-get bvar ;TODO - CHECK!! AFTER HANDLE WITH SEQ
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'box-get)
			  	    (equal? (caadr pe) 'bvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (cadddr complete_var))
			   		  (major (caddr complete_var))
			   		  (minor_str (number->string minor))
			   		  (major_str (number->string major)))
			   	(string-append
			   		"MOV (R0, FPARG(0));\n" ;env
			   		"MOV (R0, INDD(R0,"major_str"));\n"	   		
			   		"MOV (R0, INDD(R0,"minor_str"));\n"
			   		"MOV (R0, IND(R0));\n"
			   		)))
			  ;box-set pvar ;TODO - CHECK!! AFTER HANDLE WITH SEQ
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'box-set)
			  	    (equal? (caadr pe) 'pvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (caddr complete_var))
			   		  (value (caddr pe)) 
			   		  (minor_str (number->string minor)))
			   	(string-append
			   		(code-gen value major)
			   		"MOV (R1, FPARG(2+"minor_str"))"
			   		"MOV (IND(R1), R0);\n"
			   		"MOV (R0, IMM(T_VOID));\n" ;IMPORTANT TODO!! - AFTER CONST TABLE CHANGE TO SOB_VOID
			   		)))
			  ;box-set bvar ;TODO - CHECK!! AFTER HANDLE WITH SEQ
			  ((and (pair? pe) 
			  	    (equal? (car pe) 'box-set)
			  	    (equal? (caadr pe) 'bvar))
			   (let* ((complete_var (cadr pe))
			   		  (minor (cadddr complete_var))
			   		  (major (caddr complete_var))
			   		  (value (caddr pe)) 
			   		  (minor_str (number->string minor))
			   		  (major_str (number->string major)))
			   	(string-append
			   		(code-gen value major)
			   		"MOV (R1, FPARG(0));\n" ;env
			   		"MOV (R1, INDD(R1,"major_str"));\n"	
			   		"MOV (R2, INDD(R1,"minor_str"));\n"   		
			   		"MOV (IND(R2), R0);\n"
			   		"MOV (R0, IMM(T_VOID));\n" ;IMPORTANT TODO!! - AFTER CONST TABLE CHANGE TO SOB_VOID
			   		)))
			  ;else
			  (else "") 
			  	)))

(define compile-scheme-file
	(lambda (scm_src_file asm_target_file)
		(let* ((scm_content (file->string scm_src_file))
			   (match_and_remain (test-string <Sexpr> scm_content))
			   (sexprs_list (create_sexprs_list scm_content))
			   (super_parsed_list (parsed_and_hw3 sexprs_list))
			   (constant_table (build_constant_table super_parsed_list))
			   (global_var_table (build_global_var_table super_parsed_list))
			   (asm_instructions_list (build_asm_insts_list super_parsed_list))
			   (asm_instructions_string (build_asm_insts_string asm_instructions_list))
			   (asm_with_const_table (add_const_table constant_table asm_instructions_string))
			   (final_asm (add_prologue_epilgue asm_with_const_table)))
			(string->file final_asm asm_target_file))))
;super_parsed_list)))

;TODO - ONLY ONE S-EXP
(define build_asm_insts_list
	(lambda (super_parsed_list)
		(if (null? super_parsed_list)
			(list)
			(cons (add_r0_print (code-gen (car super_parsed_list) 0))
				  (build_asm_insts_list (cdr super_parsed_list))))))

;TODO - PROBABLY REMOVE
(define add_r0_print
	(lambda (asm_string)
		;(string-append asm_string "OUT(IMM(2), R0);\n ")
		asm_string))

(define build_asm_insts_string
	(lambda (insts_list)
		(if (null? insts_list)
			""
			(string-append (car insts_list) (build_asm_insts_string (cdr insts_list))))))

(define add_const_table 
	(lambda (constant_table asm_instructions_string)
		(string-append (build_asm_constant_table constant_table)
						asm_instructions_string)))

(define build_asm_constant_table
	(lambda (constant_table)
		(let* ((last_element (car (reverse constant_table)))
			   (address (car last_element))
			   (represent (caddr last_element))
		       (represent_length (length represent))
		       (malloc_need (+ address represent_length))
		       (malloc_need_str (number->string malloc_need)))
			(string-append 
				"PUSH ("malloc_need_str");\n"
				"CALL (MALLOC);\n"
				"DROP (1);\n"
				(letrec ((run (lambda (lst)
									(if (null? lst)
										""
										(let* ((element (car lst))
											   (address (car element))
											   (rep_lst (caddr element)))
											(string-append (build_string_for_element_memory address rep_lst)
											               (run (cdr lst))))))))
					(run constant_table))))))

(define build_string_for_element_memory
	(lambda (address rep_lst)
		(letrec ((run (lambda (lst num)
						(if (null? lst)
							""
							(let ((string_rep (if (symbol? (car lst))
												  (symbol->string (car lst))
												  (number->string (car lst)))))
								(string-append
									"MOV (IND("(number->string num)"), "string_rep");\n"
									(run (cdr lst) (+ num 1))))))))
			(run rep_lst address))))


; /* change to 0 for no debug info to be printed: */
; #define DO_SHOW 1

(define add_prologue_epilgue
	(lambda (asm_insts_string)
		(string-append "
#include <stdio.h>
#include <stdlib.h>

#include \"cisc.h\"

/* change to 0 for no debug info to be printed: */
#define DO_SHOW 1

#include \"debug_macros.h\"

int main()
{
START_MACHINE;

JUMP(CONTINUE);

#include \"char.lib\"
#include \"io.lib\"
#include \"math.lib\"
#include \"string.lib\"
#include \"system.lib\"
#include \"scheme.lib\"

CONTINUE:

/*TODO - should entered the constant_table*/

PUSH(FP);
MOV(FP, SP);

 #define SOB_VOID (IND(1))
 #define SOB_NIL (IND(2))
 #define SOB_FALSE (IND(3))
 #define SOB_TRUE (IND(5))

"
 asm_insts_string
"
POP(FP);

/*TODO - remove info - for debug*/
INFO;

STOP_MACHINE;

return 0;
}"
						)))



;TODO - now
(define build_constant_table
	(lambda (super_parsed_list)
		(remove-dups (build_const_table_for_each_sexpr super_parsed_list))))

(define remove-dups
	(lambda (lst)
		(if (null? lst)
			lst
			(if (member (car lst) (cdr lst))
				(remove-dups (cdr lst))
				(cons (car lst) (remove-dups (cdr lst)))))))

(define build_const_table_for_each_sexpr
	(lambda (super_parsed_list)
		(if (null? super_parsed_list)
			(list)
			(append (build_const_table_for_sexpr (car super_parsed_list))
					(build_const_table_for_each_sexpr (cdr super_parsed_list))))))

(define build_const_table_for_sexpr
	(lambda (super_parsed_sexpr)
		(let* ((full_const_list (create_const_list super_parsed_sexpr))
			   (const_list_no_dups (remove-dups full_const_list))
			   (full_sub_const_list (create_sub_const_list const_list_no_dups))
			   (sub_const_list_no_dups (remove-dups full_sub_const_list))
			   (final_list (build_final_list sub_const_list_no_dups)))
		 	final_list)))

(define create_const_list
	(lambda (sp_sexpr)
		(cond ((or (null? sp_sexpr) (atom? sp_sexpr)) (list))
			  ((and (equal? (car sp_sexpr) 'const)
			  		(not (or 	(equal? sp_sexpr `(const ,(void)))
								(equal? sp_sexpr `(const ()))
								(equal? sp_sexpr `(const #f))
								(equal? sp_sexpr `(const #t))))) 
			   (cdr sp_sexpr))
			  (else (append (create_const_list (car sp_sexpr))
			  				(create_const_list (cdr sp_sexpr)))))))

(define create_sub_const_list
	(lambda (const_list)
		(letrec ((run (lambda (element)
						(cond ((pair? element)
								`(,@(run (car element)) ,@(run (cdr element)) ,element))
							  ((vector? element)
							  	`(,@(apply append (map foo (vector->list element)))
							  	  ,element))
							  (else `(,element))))))
			(remove_nil (flatten (map run const_list))))))

(define flatten
	(lambda (lst)
   		(cond ((null? lst) lst)
         	  ((list? (car lst)) `(,@(car lst) ,@(flatten (cdr lst))))
         	  (else (cons (car lst) (flatten (cdr lst)))))))

(define remove_nil
	(lambda (lst)
		(if (null? lst)
			lst
			(if (equal? (car lst) '())
				(remove_nil (cdr lst))
				(cons (car lst) (remove_nil (cdr lst)))))))


(define build_final_list
	(lambda (sub_const_list_no_dups)
		(let* ((firsts (build_firsts))
			   (rests (build_rest sub_const_list_no_dups firsts 7)))
			(cons `(1 ,(void) (T_VOID)) rests))))

(define build_firsts
	(lambda ()
		(list 
			  `(2 () (T_NIL))
			  `(3 #t (T_BOOL 1))
			  `(5 #f (T_BOOL 0)))))

(define build_rest
	(lambda (sub_list acc_list next_available)
		(if (null? sub_list)
			acc_list
			(let* ((current_element (build_const_list_element (car sub_list) next_available acc_list))
				  (element_length (length (caddr current_element))))
				(build_rest (cdr sub_list)
					        (append acc_list `(,current_element))
					        (+ next_available element_length))))))

(define build_const_list_element
	(lambda (element next_available acc_list)
		(cond ((number? element)
			   `(,next_available ,element (T_INTEGER ,element)))
			  ((pair? element)
			   `(,next_available ,element (T_PAIR ,(search_element (car element) acc_list)
			   									  ,(search_element (cdr element) acc_list))))
			  (else '()))))

(define search_element
	(lambda (element lst)
		(if (null? lst)
			0
			(let* ((current (car lst))
				   (current_value (cadr current)))
			 	(if (equal? current_value element)
			 		(car current)
			 		(search_element element (cdr lst)))))))

;TODO
(define build_global_var_table
	(lambda (super_parsed_list)
		(list)))

(define parsed_and_hw3 
	(lambda (sexprs_list)
		(if (null? sexprs_list)
			(list)
			(cons (annotate-tc
				   	 (pe->lex-pe
				   	   (box-set
				   	      (remove-applic-lambda-nil
				   	      	(eliminate-nested-defines 
				   	      		(parse (car sexprs_list)))))))
				   (parsed_and_hw3 (cdr sexprs_list))))))

(define create_sexprs_list
	(lambda (scm_content)
		(if (equal? scm_content "")
			(list)
			(let* ((match_and_remain (test-string <Sexpr> scm_content))
				   (match (cadar match_and_remain))
				   (remain (cadadr match_and_remain)))
				(cons match (create_sexprs_list remain))))))



(define file->string
	(lambda (in-file)
		(let ((in-port (open-input-file in-file)))
			(letrec ((run
						(lambda ()
							(let ((ch (read-char in-port)))
								(if (eof-object? ch)
									(begin
										(close-input-port in-port)
										'())
									(cons ch (run)))))))

				(list->string (run))))))


(define string->file
	(lambda (string out-file)
		(let ((out-port (open-output-file out-file)))
			(begin (display string out-port)
				   (close-output-port out-port)))))
