/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char *name, int mut, char *type, char *func_sig);
    static Symbol lookup_symbol(char *name);
    static void dump_symbol();

    /* Global variables */
    bool HAS_ERROR = false;
    int current_addr = -1;
    int current_level = -1;
    SymbolManager manager;
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
    int label_index = 0;
    int if_index = 0;
    int while_index = 0;
    int loop_index = 0;
    int array_size = 0;
    int foreach_index = 0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    std::pair<char *, char *> *s_pair;
    /* ... */
    std::vector<char *> *s_list;
    std::vector<std::pair<char *, char *> *> *s_pair_list;
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token ADD MINUS MUL DIV REM
%token GTR LSS GEQ LEQ EQL NEQ LOR LAND NOT
%token ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ID ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> TypeName AssignOrNot ReturnTypeOrNot IDInference
%type <s_val> Expression Literal Operand
%type <s_val> add_op mul_op cmp_op unary_op assign_op
%type <s_val> AndExpr ComparisonExpr AdditionExpr MultiplyExpr UnaryExpr CastExpr

%type <s_val> Name
%type <s_list> NameList
%type <s_pair> NameAndType
%type <s_pair_list> NameAndTypeList

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : FUNC ID '(' NameAndTypeList ')' ReturnTypeOrNot '{' { 
        
     


        current_addr = -1;
        printf("func: %s\n", $<s_val>2); 
        
        int idx = 0;
        char paramType[10];
        char returnType;
        for (auto nameAndType : *$4) {
            char *name = nameAndType->first;
            char *type = nameAndType->second;
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                paramType[idx++] = (type[0] + 'A' - 'a'); 
            }
        }   
        if (idx == 0) {
            paramType[idx++] = 'V';
        }
        paramType[idx] = '\0';
        returnType = (strcmp($<s_val>6, "None") == 0 ? 'V' : ($<s_val>6)[0] + 'A' - 'a');
        
        char* func_sig = (char*)malloc(sizeof(char) * 20);
        sprintf(func_sig, "(%s)%c", paramType, returnType);
        insert_symbol($<s_val>2, -1, (char *)"func", func_sig); 

        create_symbol();
        for (auto nameAndType : *$4) {
            char *name = nameAndType->first;
            char *type = nameAndType->second;
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                insert_symbol(name, 0, type, (char *)"-"); 
            }
        }

        if(strcmp($<s_val>2,"main")==0){
            CODEGEN(".method public static main([Ljava/lang/String;)V\n");
            CODEGEN(".limit stack 100\n");
            CODEGEN(".limit locals 100\n");
        }
        else{
            if(returnType=='B')
                returnType = 'Z';
            if(paramType[0]=='V'){
                CODEGEN(".method public static %s()%c\n",$<s_val>2,returnType);
            } 
            else{
                CODEGEN(".method public static %s(%s)%c\n",$<s_val>2,paramType,returnType);
            }
            CODEGEN(".limit stack 20\n");
            CODEGEN(".limit locals 20\n");
        }
        g_indent_cnt++;

    } 
    StatementList '}' { 
        dump_symbol();
        if(strcmp($<s_val>6,"i32")==0||strcmp($<s_val>6,"bool")==0){
            CODEGEN("ireturn\n");
        }
        else if(strcmp($<s_val>6,"f32")==0){
            CODEGEN("freturn\n");
        }
        else if(strcmp($<s_val>6,"str")==0){
            CODEGEN("areturn\n");
        }
        else{
            CODEGEN("return\n");
        }
        g_indent_cnt--;
        CODEGEN(".end method\n");
    
    }
;

FunctionCall
    : ID '(' NameList ')' {
        for (auto name : *$3 ) {
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                Symbol s = lookup_symbol(name);
                printf("IDENT (name=%s, address=%d)\n", s.name, s.addr);
            }
        }
        Symbol s = lookup_symbol($<s_val>1);
        printf("call: %s%s\n", s.name, s.func_sig);
        if(s.func_sig[strlen(s.func_sig)-1]=='B')
            s.func_sig[strlen(s.func_sig)-1] = 'Z';
        if(s.func_sig[1]=='V'){
            CODEGEN("invokestatic Main/%s()%c\n",s.name,s.func_sig[3]);
        } else{
            CODEGEN("invokestatic Main/%s%s\n",s.name,s.func_sig);
        }
    }
;

NameAndTypeList
    : NameAndTypeList ',' NameAndType { $$->push_back($3); }
    | NameAndType { $$ = new std::vector<std::pair<char *, char *> *>; $$->push_back($1); }
;

NameAndType
    : ID ':' TypeName { $$ = new std::pair<char *, char *> {$<s_val>1, $<s_val>3}; }
    | { $$ = new std::pair<char *, char *> {(char *)"None", (char *)"None"}; }
;

NameList
    : NameList ',' Name { $$->push_back($3); }
    | Name { $$ = new std::vector<char *>; $$->push_back($1); }
;

Name
    : IDInference { $$ = $<s_val>1; }
    | { $$ = (char *)"None"; }
;

ReturnTypeOrNot
    : ARROW TypeName { $$ = $2; }
    | { $$ = (char *)"None"; }
;

CompoundStatement
    : '{' { create_symbol(); } StatementList '}' { dump_symbol(); }
    |
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
    : PrintStatement
    | VariableDeclaration
    | TwoDArrayDeclaration
    | ArrayDeclaration
    | AssignStatement
    | CompoundStatement
    | IfStatement
    | WhileStatement
    | ForStatement
    | ReturnStatement
    | Expression ';'
    | BreakStatement
;

BreakStatement
    : BREAK Expression ';' {
        CODEGEN("goto label_loop%d\n",loop_index+1);
    }
    | BREAK ';'
;

VariableDeclaration
    : LET ID ':' TypeName AssignOrNot ';' { 
        insert_symbol($<s_val>2, 0, $<s_val>4, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>2); 
        
        if (strcmp($<s_val>4, "f32") == 0) {
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($<s_val>4, "str") == 0) {
            CODEGEN("astore %d\n", s.addr);
        }
        else{
            CODEGEN("istore %d\n",s.addr);
        }
    }
    | LET ID ':' '&' TypeName AssignOrNot ';' { 
        insert_symbol($<s_val>2, 0, $<s_val>5, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>2); 
        
        if (strcmp($<s_val>5, "f32") == 0) {
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($<s_val>5, "str") == 0) {
            CODEGEN("astore %d\n", s.addr);
        }
        else{
            CODEGEN("istore %d\n",s.addr);
        }
    }
    | LET ID AssignOrNot ';' { 
        insert_symbol($<s_val>2, 0, $<s_val>3, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>2); 
        if (strcmp($3, "f32") == 0) {
            if(strcmp($3,"null")==0){
                CODEGEN("ldc 0.0\n");
            }
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($3, "str") == 0) {
            if(strcmp($3,"null")==0){
                CODEGEN("ldc \"\"\n");
            }
            CODEGEN("astore %d\n", s.addr);
        }
        else{
            if(strcmp($3,"null")==0){
                CODEGEN("ldc 0\n");
            }
            CODEGEN("istore %d\n",s.addr);
        }
    }
    | LET MUT ID ':' TypeName AssignOrNot ';' { 
        insert_symbol($<s_val>3, 1, $<s_val>5, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>3); 
        
        if (strcmp($<s_val>5, "f32") == 0) {
            if(strcmp($6,"null")==0){
                CODEGEN("ldc 0.0\n");
            }
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($<s_val>5, "str") == 0) {
            if(strcmp($6,"null")==0){
                CODEGEN("ldc \"\"\n");
            }
            CODEGEN("astore %d\n", s.addr);
        }
        else{
            if(strcmp($6,"null")==0){
                CODEGEN("ldc 0\n");
            }
            CODEGEN("istore %d\n",s.addr);
        }
    }
    | LET MUT ID ':' '&' TypeName AssignOrNot ';' { 
        insert_symbol($<s_val>3, 1, $<s_val>6, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>3); 
        
        if (strcmp($<s_val>6, "f32") == 0) {
            if(strcmp($7,"null")==0){
                CODEGEN("ldc 0.0\n");
            }
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($<s_val>6, "str") == 0) {
            if(strcmp($7,"null")==0){
                CODEGEN("ldc \"\"\n");
            }
            CODEGEN("astore %d\n", s.addr);
        }
        else{
            if(strcmp($7,"null")==0){
                CODEGEN("ldc 0\n");
            }
            CODEGEN("istore %d\n",s.addr);
        }
    }
    | LET MUT ID AssignOrNot ';' { 
        insert_symbol($<s_val>3, 1, $<s_val>4, (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>3); 
        if (strcmp($<s_val>4, "f32") == 0) {
            CODEGEN("fstore %d\n", s.addr);
        }
        else if (strcmp($<s_val>4, "str") == 0) {
            CODEGEN("astore %d\n", s.addr);
        }
        else if(strcmp($<s_val>4, "i32") == 0||strcmp($<s_val>4,"bool")==0){
            CODEGEN("istore %d\n",s.addr);
        }
    }
;
TwoDArrayDeclaration
    : LET MUT ID ':' '[' '[' TypeName ';' INT_LIT ']' ';' INT_LIT ']' {
        insert_symbol($<s_val>3, 0, (char *)"array", (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>3);
        CODEGEN("ldc %d\n", $12);
        CODEGEN("ldc %d\n", $9);
        CODEGEN("multianewarray [[I 2\n");
        CODEGEN("astore %d\n",s.addr);
        for(int i=0;i<$12;i++){
            for(int j=0;j<$9;j++){
                CODEGEN("aload %d\n",s.addr);
                CODEGEN("ldc %d\n",i);
                CODEGEN("aaload\n");
                CODEGEN("ldc %d\n",j);
            }
        }
    } TwoDArrayAssignOrNot ';'
;
TwoDArrayAssignOrNot
    : ASSIGN '[' '[' INT_LIT ';' INT_LIT ']' ';' INT_LIT ']' {
        for(int i=0;i<$6;i++){
            for(int j=0;j<$9;j++){
                CODEGEN("ldc %d\n",$4);
                CODEGEN("iastore\n");
            }
        }
    }
    |
;
ArrayDeclaration
    : LET ID ':' '[' TypeName ';' INT_LIT ']' {
        insert_symbol($<s_val>2, 0, (char *)"array", (char *)"-"); 
        Symbol s = lookup_symbol($<s_val>2);
        CODEGEN("ldc %d\n", $7);
        CODEGEN("newarray int\n");
        CODEGEN("astore %d\n",s.addr);
        for(int i=0;i<$7;i++){
            CODEGEN("aload %d\n",s.addr);
        }
    } AssignOrNot ';' 
;

AssignOrNot
    : ASSIGN Expression { $$ = $2; } 
    | ASSIGN '[' ExpressionList ']'
    | {$$=(char *)"null";}
;

ExpressionList
    : ExpressionList ',' Expression {
        CODEGEN("ldc %d\n",array_size);
        CODEGEN("swap\n");
        CODEGEN("iastore\n");
        array_size++;
    }
    | Expression {
        CODEGEN("ldc %d\n",array_size);
        CODEGEN("swap\n");
        CODEGEN("iastore\n");
        array_size++;
    }
;

PrintStatement
    : PRINTLN '(' Expression ')' ';' { 
        printf("PRINTLN %s\n", $<s_val>3);
        char* type;
        if(strcmp($<s_val>3,"i32")==0||strcmp($<s_val>3,"array")==0){
            type = "I";
        }
        else if(strcmp($<s_val>3,"f32")==0){
            type = "F";
        }
        else if(strcmp($<s_val>3,"bool")==0){
            type = "Z";
        }
        else{
            type = "Ljava/lang/String;";
        }
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/io/PrintStream/println(%s)V\n",type);
    }
    | PRINT '(' Expression ')' ';' { 
        printf("PRINT %s\n", $<s_val>3); 
        printf("PRINTLN %s\n", $<s_val>3);
        char* type;
        if(strcmp($<s_val>3,"i32")==0){
            type = "I";
        }
        else if(strcmp($<s_val>3,"f32")==0){
            type = "F";
        }
        else if(strcmp($<s_val>3,"bool")==0){
            type = "Z";
        }
        else{
            type = "Ljava/lang/String;";
        }
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/io/PrintStream/print(%s)V\n",type);
    }
;

AssignStatement
    : ID  assign_op {
        if(strcmp($2,"ASSIGN")!=0){
            Symbol s = lookup_symbol($<s_val>1);
            if (strcmp(s.type, "f32") == 0) {
                CODEGEN("fload %d\n", s.addr);
            }
            else if (strcmp(s.type, "str") == 0) {
                CODEGEN("aload %d\n", s.addr);
            }
            else{
                CODEGEN("iload %d\n",s.addr);
            }
        }
    } 
    Expression ';' { 
        Symbol s = lookup_symbol($<s_val>1);
        if (strcmp(s.type, "undefined") == 0) {
            g_has_error = true;
            printf("error:%d: undefined: %s\n", yylineno+1, $<s_val>1);
        } else {
            printf("%s\n", $2);
            if(strcmp($2,"ADD_ASSIGN")==0){
                if(strcmp(s.type, "f32") == 0){
                    CODEGEN("fadd\n");
                }
                else if(strcmp(s.type, "i32") == 0){
                    CODEGEN("iadd\n");
                }
            }
            else if(strcmp($2,"SUB_ASSIGN")==0){
                if(strcmp(s.type, "f32") == 0){
                    CODEGEN("fsub\n");
                }
                else if(strcmp(s.type, "i32") == 0){
                    CODEGEN("isub\n");
                }
            }
            else if(strcmp($2,"MUL_ASSIGN")==0){
                if(strcmp(s.type, "f32") == 0){
                    CODEGEN("fmul\n");
                }
                else if(strcmp(s.type, "i32") == 0){
                    CODEGEN("imul\n");
                }
            }
            else if(strcmp($2,"DIV_ASSIGN")==0){
                if(strcmp(s.type, "f32") == 0){
                    CODEGEN("fdiv\n");
                }
                else if(strcmp(s.type, "i32") == 0){
                    CODEGEN("idiv\n");
                }
            }
            else if(strcmp($2,"REM_ASSIGN")==0){
                CODEGEN("irem\n");
            }
            if (strcmp(s.type, "f32") == 0) {
                CODEGEN("fstore %d\n", s.addr);
            }
            else if (strcmp(s.type, "str") == 0) {
                CODEGEN("astore %d\n", s.addr);
            }
            else{
                CODEGEN("istore %d\n",s.addr);
            }
        }
    }
    | ID '[' INT_LIT ']' '[' INT_LIT ']' {
        Symbol s = lookup_symbol($<s_val>1);
        CODEGEN("aload %d\n",s.addr);
        CODEGEN("ldc %d\n",$3);
        CODEGEN("aaload\n");
        CODEGEN("ldc %d\n",$6);
    } assign_op Expression ';'{
        CODEGEN("iastore\n");
    }
;
assign_op 
    : ASSIGN { $$ = (char *)"ASSIGN"; }
    | ADD_ASSIGN { $$ = (char *)"ADD_ASSIGN"; }
    | SUB_ASSIGN { $$ = (char *)"SUB_ASSIGN"; }
    | MUL_ASSIGN { $$ = (char *)"MUL_ASSIGN"; }
    | DIV_ASSIGN { $$ = (char *)"DIV_ASSIGN"; }
    | REM_ASSIGN { $$ = (char *)"REM_ASSIGN"; }
;

TypeName
    : INT { $$ = (char *)"i32"; }
    | FLOAT { $$ = (char *)"f32"; }
    | BOOL { $$ = (char *)"bool"; }
    | STR { $$ = (char *)"str"; }
;

Expression
    : Expression LOR AndExpr { printf("LOR\n"); $$ = $3;CODEGEN("ior\n"); }
    | FunctionCall
    | ComparisonExpr { $$ = $1; }
    | LoopExpression
;

LoopExpression
    : LOOP {
        g_indent_cnt--;
        CODEGEN("label_loop%d:\n",loop_index);
        g_indent_cnt++;
    } CompoundStatement {
        CODEGEN("goto label_loop%d\n",loop_index);
        g_indent_cnt--;
        CODEGEN("label_loop%d:\n",loop_index+1);
        g_indent_cnt++;
        loop_index+=2;
    }
;
AndExpr
    : ComparisonExpr {$$ = $1; }
    | AndExpr LAND ComparisonExpr {
        printf("LAND\n");
        $$ = $3;
        CODEGEN("iand\n");
    }
ComparisonExpr
    : AdditionExpr { $$ = $1; }
    | ComparisonExpr cmp_op AdditionExpr { 
        if (strcmp($1, $3) != 0) {
            g_has_error = true;
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        else{
            printf("%s\n", $2); 
            if(strcmp($1,"i32")==0||strcmp($1,"bool")==0){
                CODEGEN("isub\n");
            }
            else if(strcmp($1,"f32")==0){
                CODEGEN("fcmpl\n");
            }
            if(strcmp($2,"EQL")==0){
                CODEGEN("ifeq label%d\n",label_index);
            }
            else if(strcmp($2,"NEQ")==0){
                CODEGEN("ifne label%d\n",label_index);
            }
            else if(strcmp($2,"LSS")==0){
                CODEGEN("iflt label%d\n",label_index);
            } 
            else if(strcmp($2,"LEQ")==0){
                CODEGEN("ifle label%d\n",label_index);
            }
            else if(strcmp($2,"GTR")==0){
                CODEGEN("ifgt label%d\n",label_index);
            }
            else if(strcmp($2,"GEQ")==0){
                CODEGEN("ifge label%d\n",label_index);
            }
            CODEGEN("iconst_0\n");
            CODEGEN("goto label%d\n",label_index+1);
            g_indent_cnt--;
            CODEGEN("label%d:\n",label_index);
            g_indent_cnt++;
            CODEGEN("iconst_1\n");
            g_indent_cnt--;
            CODEGEN("label%d:\n",label_index+1);
            g_indent_cnt++;
            label_index+=2;
        }
        $$ = $3;
    }
;
cmp_op
    : EQL { $$ = (char *)"EQL"; }
    | NEQ { $$ = (char *)"NEQ"; }
    | LSS { $$ = (char *)"LSS"; }
    | LEQ { $$ = (char *)"LEQ"; }
    | GTR { $$ = (char *)"GTR"; }
    | GEQ { $$ = (char *)"GEQ"; }
;

AdditionExpr
    : MultiplyExpr { $$ = $1; }
    | AdditionExpr add_op MultiplyExpr { 
        if (strcmp($1, $3) != 0) {
            g_has_error = true;
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        printf("%s\n", $2); $$ = $3; 
        if(strcmp($2,"ADD")==0){
            if(strcmp($1,"i32")==0){
                CODEGEN("iadd\n");
            }
            else if(strcmp($1,"f32")==0){
                CODEGEN("fadd\n");
            }
        }
        else if(strcmp($2,"SUB")==0){
            if(strcmp($1,"i32")==0){
                CODEGEN("isub\n");
            }
            else if(strcmp($1,"f32")==0){
                CODEGEN("fsub\n");
            }
        }
    }
;
add_op
    : ADD { $$ = (char *)"ADD"; }
    | MINUS { $$ = (char *)"SUB"; }
;

MultiplyExpr
    : UnaryExpr { $$ = $1; }
    | MultiplyExpr mul_op UnaryExpr { 
        if (strcmp($1, $3) != 0) {
            g_has_error = true;
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        printf("%s\n", $2); $$ = $3; 
        if(strcmp($2,"MUL")==0){
            if(strcmp($1,"i32")==0){
                CODEGEN("imul\n");
            }
            else if(strcmp($1,"f32")==0){
                CODEGEN("fmul\n");
            }
        }
        else if(strcmp($2,"DIV")==0){
            if(strcmp($1,"i32")==0){
                CODEGEN("idiv\n");
            }
            else if(strcmp($1,"f32")==0){
                CODEGEN("fdiv\n");
            }
        }
        else if(strcmp($2,"REM")==0){
            CODEGEN("irem\n");
        }
        else if(strcmp($2,"LSHIFT")==0){
            CODEGEN("ishl\n");
        }
        else if(strcmp($2,"RSHIFT")==0){
            CODEGEN("iushr\n");
        }

    }
;
mul_op 
    : MUL { $$ = (char *)"MUL"; }
    | DIV { $$ = (char *)"DIV"; }
    | REM { $$ = (char *)"REM"; }
    | LSHIFT { $$ = (char *)"LSHIFT"; }
    | RSHIFT { $$ = (char *)"RSHIFT"; }
;

UnaryExpr
    : CastExpr { $$ = $1; }
    | unary_op UnaryExpr { 
        printf("%s\n", $1); $$ = $2; 
        if(strcmp($1,"NEG")==0){
            if(strcmp($2,"i32")==0){
                CODEGEN("ineg\n");
            }
            else if(strcmp($2,"f32")==0){
                CODEGEN("fneg\n");
            }
        }
        else if(strcmp($1,"NOT")==0){
            CODEGEN("iconst_1\n");
            CODEGEN("ixor\n");
        }
        
    }
;
unary_op 
    : MINUS { $$ = (char *)"NEG"; }
    | NOT { $$ = (char *)"NOT"; }
;

CastExpr
    : Operand
    | Operand AS TypeName { 
        printf("%c2%c\n", $1[0], $3[0]); $$ = $3; 
        CODEGEN("%c2%c\n", $1[0], $3[0]);
    }
;

Operand
    : Literal { $$ = $1; }
    | IDInference { $$ = $1; }
    | '(' Expression ')' { $$ = $2; }
    | IDInference '[' Expression ']' { 
        $$ = (char *)"array"; 
        CODEGEN("iaload\n");
    }
    | IDInference '[' Expression ']' {
        CODEGEN("aaload\n");
    } '[' Expression ']' {
        CODEGEN("iaload\n");
    }
    | Slice
;

IDInference
    : ID { 
        Symbol s = lookup_symbol($<s_val>1);
        if (strcmp(s.type, "undefined") == 0) {
            g_has_error = true;
            printf("error:%d: undefined: %s\n", yylineno+1, $<s_val>1);
        } else {
            printf("IDENT (name=%s, address=%d)\n", s.name, s.addr);
            if(strcmp(s.type,"i32")==0||strcmp(s.type,"bool")==0){
                CODEGEN("iload %d\n",s.addr);
            }
            else if(strcmp(s.type,"f32")==0){
                CODEGEN("fload %d\n",s.addr);
            }
            else if(strcmp(s.type,"str")==0){
                CODEGEN("aload %d\n",s.addr);
            }
            else if(strcmp(s.type,"array")==0){
                CODEGEN("aload %d\n",s.addr);
            }
        }
        $$ = s.type;
    }
;

Slice 
    : '&' IDInference '[' SliceFormat ']' 
;

SliceFormat
    : Expression DoubleDot Expression {
        CODEGEN("invokevirtual java/lang/String/substring(II)Ljava/lang/String;\n");
    }
    | Expression DoubleDot {
        CODEGEN("invokevirtual java/lang/String/substring(I)Ljava/lang/String;\n");
    }
    | DoubleDot Expression {
        CODEGEN("ldc 0\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/lang/String/substring(II)Ljava/lang/String;\n");
        
    }
;

DoubleDot
    : DOTDOT { printf("DOTDOT\n"); }
;

Literal
    : INT_LIT { printf("INT_LIT %d\n", $<i_val>1); $$ = (char *)"i32";CODEGEN("ldc %d\n",  $<i_val>1); }
    | FLOAT_LIT { printf("FLOAT_LIT %f\n", $<f_val>1); $$ = (char *)"f32"; CODEGEN("ldc %f\n", $<f_val>1);}
    | '\"' STRING_LIT '\"' { printf("STRING_LIT \"%s\"\n", $<s_val>2); $$ = (char *)"str";CODEGEN("ldc \"%s\"\n", $<s_val>2); }
    | '\"' '\"' { printf("STRING_LIT \"\"\n"); $$ = (char *)"";CODEGEN("ldc \"\"\n"); } 
    | TRUE { printf("bool TRUE\n"); $$ = (char *)"bool"; CODEGEN("iconst_1\n");}
    | FALSE { printf("bool FALSE\n"); $$ = (char *)"bool"; CODEGEN("iconst_0\n");}
;

IfStatement 
    : IF Expression {
        CODEGEN("ifeq label_if%d\n",if_index);
    } CompoundStatement ElseStatement{
        g_indent_cnt--;
        CODEGEN("label_if%d:\n",if_index);
        g_indent_cnt++;
        if_index++;
    }
;
ElseStatement
    : ELSE {
        CODEGEN("goto label_if%d\n",if_index+1);
        g_indent_cnt--;
        CODEGEN("label_if%d:\n",if_index);
        g_indent_cnt++;
        if_index++;
    } CompoundStatement
    | 
;
WhileStatement
    : WHILE{
        g_indent_cnt--;
        CODEGEN("label_while%d:\n",while_index);
        g_indent_cnt++;
    } Expression {
        CODEGEN("ifeq label_while%d\n",while_index+1);
    } CompoundStatement {
        CODEGEN("goto label_while%d\n",while_index);
        while_index++;
        g_indent_cnt--;
        CODEGEN("label_while%d:\n",while_index);
        g_indent_cnt++;
        while_index++;
    }
;

ForStatement
    : FOR ID {
        CODEGEN("iconst_0\n");
        CODEGEN("istore 99\n");
        g_indent_cnt--;
        CODEGEN("label_foreach%d:\n",foreach_index);
        g_indent_cnt++;
    } IN ID '{' {
        create_symbol();
        insert_symbol($<s_val>2, 0, (char *)"i32", (char *)"-"); 
        Symbol arr = lookup_symbol($<s_val>5);
        Symbol s = lookup_symbol($<s_val>2);
        CODEGEN("iload 99\n");
        CODEGEN("aload %d\n",arr.addr);
        CODEGEN("arraylength\n");
        CODEGEN("isub\n");
        CODEGEN("ifge label_foreach%d\n",foreach_index+1);
        CODEGEN("aload %d\n",arr.addr);
        CODEGEN("iload 99\n");
        CODEGEN("iaload\n");
        CODEGEN("istore %d\n",s.addr);
    } StatementList '}' { 
        dump_symbol(); 
        CODEGEN("iinc 99 1\n");
        CODEGEN("goto label_foreach%d\n",foreach_index);
        g_indent_cnt--;
        CODEGEN("label_foreach%d:\n",foreach_index+1);
        g_indent_cnt++;
        foreach_index+=2;
    }
;

ReturnStatement
    : RETURN Expression ';' { printf("breturn\n"); CODEGEN("ireturn\n");}
    | Expression { printf("breturn\n"); }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    yylineno = 0;
    create_symbol(); 
    yyparse();
    dump_symbol();

	printf("Total lines: %d\n", yylineno);
    fclose(fout);
    fclose(yyin);
    
    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

static void create_symbol() {
    current_level++;
    SymbolTable table;
    manager.push_back(table);
    printf("> Create symbol table (scope level %d)\n", current_level);
}

static void insert_symbol(char *name, int mut, char *type, char *func_sig) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, current_addr, current_level);
    Symbol symbol {(int)manager[current_level].size(), name, mut, type, current_addr, yylineno+1, func_sig};
    manager[current_level].push_back(symbol);
    current_addr++;
}

static Symbol lookup_symbol(char *name) {
    for (int i=current_level; i>=0; i--) {
        SymbolTable table = manager[i];
        for (Symbol s: table) {
            if (strcmp(s.name, name) == 0 ) {
                return s;
            }
        }
    }
    Symbol none {-1, (char *)"", -1, (char *)"undefined", -1, -1, (char *)""};
    return none;
}

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", current_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    for (Symbol s: manager[current_level]) {
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            s.index, s.name, s.mut, s.type, s.addr, s.lineno, s.func_sig);
    }
    manager.pop_back();
    current_level--;
}