
#scope_module

assert :: (arg: bool, message := "", args: .. Any, loc := #caller_location) #no_debug #expand {
    if !arg {
        if context.typechecker.current_block {
            print("\n(In block): %\n", node_location_string(context.typechecker.current_block));
        }

        assert_helper(message, ..args, loc);
        debug_break();
    }
}

Parser :: struct {
    tokens: [] Token;
    token_index: int;

    block_stack: [..] *Ast_Block;

    source_code_lines: [] string;

    error: bool;
    wanted: [] Token_Kind;
    got: Token_Kind;
    custom_report: string;
    error_location: Source_Location;
}

#add_context parser: Parser;

Make_Ast :: ($T: Type) -> *T {
    node := New(T);
    node.location = current_token().location;
    return node;
}

push_block :: (block: *Ast_Block) {
    assert(block && block.block_type != .NONE);

    if context.parser.block_stack.count {
        block.parent = peek(context.parser.block_stack);
    }

    array_add(*context.parser.block_stack, block);
}

pop_block :: () -> *Ast_Block {
    return pop(*context.parser.block_stack);
}

check_statement_allowed_in_block :: (ast: *Ast_Node) {
    assert(!!context.parser.block_stack.count);

    check_statement :: (ast: *Ast_Node) -> bool, string {
        block_type := peek(context.parser.block_stack).block_type;
        str := stringify_statement(ast);

        if ast.kind == .JAI_CODE return true, "";

        if block_type == {
          case .TOP_LEVEL;
            if ast.kind != .DECLARATION {
                return false, "Expected a declaration at top level";
            }

            decl := cast(*Ast_Declaration) ast;
            if !decl.constant {
                return false, "Non-constant declaration at top level";
            }

          case .MODULE;
          case .SEQUENTIAL;
            if ast.kind == .IF return true, "";
            if ast.kind == .FOR return true, "";
            if ast.kind == .DECLARATION {
                decl := cast(*Ast_Declaration) ast;
                if decl.constant return true, "";
            }
            if ast.kind == .SWITCH return true, "";
            if ast.kind == .ASSIGNMENT {
                ass := cast(*Ast_Assignment) ast;
                if ass.type != .SEQUENTIAL {
                    return false, "Sequential blocks may only contain sequential assignments (<=), not combinational ones (=)";
                }

                return true, "";
            }

            return false, tprint("This kind of statement (%) is not allowed in a sequential block", str);
        }

        return true, "";
    }

    result, report := check_statement(ast);

    if !result {
        using context.parser;

        error = true;
        custom_report = report;
        error_location = ast.location;
    }
}

stringify_statement :: (ast: *Ast_Node) -> string {
    if !ast return "";

    if ast.kind == {
      case .SEQUENTIAL_CIRCUIT;
        return "Sequential Block";

      case .COMBINATIONAL_CIRCUIT;
        return "Combinational Block";

      case .DECLARATION;
        decl := cast(*Ast_Declaration) ast;
        if decl.constant return "Constant Declaration";
        return "Declaration";

      case .IF;
        return "If";

      case .FOR;
        return "For";

      case .SWITCH;
        return "Switch";

      case .ASSIGNMENT;
        ass := cast(*Ast_Assignment) ast;
        if ass.type == .COMBINATIONAL return "Combinational Assignment";
        return "Sequential Assignment";

      case .JAI_CODE;
        return "Jai Code";
    }

    return tprint("%", ast.kind);
}

operator_info :: Binary_Operator_Info.[
    .{ .OPERATOR_DOT,               "",    "",           14 },
    .{ .OPERATOR_ADD,               "+",   "$add",       10 },
    .{ .OPERATOR_SUBTRACT,          "-",   "$sub",       10 },
    .{ .OPERATOR_MULTIPLY,          "*",   "$mul",       11 },
    .{ .OPERATOR_DIVIDE,            "/",   "$div",       11 },
    .{ .OPERATOR_MODULO,            "%",   "$mod",       11 },
    .{ .OPERATOR_BIT_OR,            "|",   "$or",        3  },
    .{ .OPERATOR_BIT_AND,           "&",   "$and",       5  },
    .{ .OPERATOR_BIT_XOR,           "^",   "$xor",       7  },
    .{ .OPERATOR_LESS_THAN,         "<",   "$lt",        8  },
    .{ .OPERATOR_GREATER_OR_EQUAL,  ">=",  "$ge",        8  },
    .{ .OPERATOR_LESS_OR_EQUAL,     "<=",  "$le",        8  },
    .{ .OPERATOR_GREATER_THAN,      ">",   "$gt",        8  },
    .{ .OPERATOR_EQUALS,            "==",  "$eq",        6  },
    .{ .OPERATOR_NOT_EQUAL,         "!=",  "$ne",        6  },
    .{ .OPERATOR_LOGICAL_OR,        "||",  "$logic_or",  1  },
    .{ .OPERATOR_WIDTH,             "'",   "",           13 },
    .{ .OPERATOR_LOGICAL_AND,       "&&",  "$logic_and", 2  },
    .{ .OPERATOR_SHIFT_LEFT,        "<<",  "$shl",       9  },
    .{ .OPERATOR_SHIFT_RIGHT,       ">>",  "$shr",       9  },
    .{ .OPERATOR_SHIFT_LEFT_ARITH,  "<<<", "",           9  },
    .{ .OPERATOR_SHIFT_RIGHT_ARITH, ">>>", "",           9  },
    .{ .OPERATOR_REPEAT,            "",    "",           12 },
];

Binary_Operator_Info :: struct {
    token: Token_Kind;
    verilog_string: string;
    rtlil_cell_type: string;
    precedence: int;

    // Could do this once the Jai compiler supports quick lambdas in struct literals
    // result_width: (left: int, right: int) -> int;
}

get_operator_info :: (token: Token_Kind) -> *Binary_Operator_Info {
    for *operator_info if it.token == token return it;

    assert(false, tprint("Tried to get operator info for '%'\n", token));
    return null;
}

parse :: (tokens: [] Token) -> *Ast_Block {
    parser := *context.parser;
    parser.tokens = tokens;

    top_level := Make_Ast(Ast_Block);
    top_level.block_type = .TOP_LEVEL;

    push_block(top_level);

    statements: [..] *Ast_Node;
    defer top_level.statements = statements;

    while true {
        if allow(.EOT) {
            break;
        }

        s := parse_statement();

        if s {
            check_statement_allowed_in_block(s);
            array_add(*statements, s);
        }

        if parser.error {
            print("\n");

            if parser.custom_report {
                print("Error: %.\n", parser.custom_report);
            } else {
                print("Error: Wanted %, got %.\n", stringify_token(parser.wanted[0]), stringify_token(parser.got));
            }

            loc := context.parser.error_location;
            line := context.parser.source_code_lines[loc.line];

            first := line;
            first.count = loc.start_char;

            second := line;
            second.data += loc.start_char;
            second.count = loc.end_char - loc.start_char;

            third := line;
            third.data += loc.end_char;
            third.count -= loc.end_char;

            print("\n(line %): %[31m%[0m%\n", loc.line, first, second, third);

            return top_level;
        }
    }

    pop_block();
    return top_level;
}

parse_statement :: () -> *Ast_Node {

    if peek(.OPEN_BRACE) return parse_assignment(); // Left hand side concatenation

    if peek(.IDENTIFIER) {
        if peek(.COLON, distance = 2) {
            decl := parse_declaration();

            if current_token().kind != .CLOSED_BRACE && current_token().kind != .SEMICOLON {
                expect(.SEMICOLON);
            }

            return decl;
        }

        if peek(.EQUALS, .OPERATOR_LESS_OR_EQUAL, .OPERATOR_DOT, .OPEN_BRACKET, distance = 2) {
            return parse_assignment();
        }

        using context.parser;
        parse_error("Expected this expression to be an assignment or a declaration, but it was followed by a token of kind %", stringify_token(tokens[token_index+1].kind));

        return null;
    }

    if allow(.KEYWORD_if) {
        _if := Make_Ast(Ast_If);
        _if.condition = parse_expression();

        // Control statements inherit the block type they're in (a sequential block is still sequential under an if, etc.)
        parent := peek(context.parser.block_stack);
        _if.block = parse_block(parent.block_type);

        if allow(.KEYWORD_else) {
            _if.else_block = parse_block(parent.block_type);
        }

        return _if;
    }

    if allow(.KEYWORD_for) {
        _for := Make_Ast(Ast_For);

        expect(.IDENTIFIER);
        _for.index = Make_Ast(Ast_Declaration);
        _for.index.name = current_token().string_value;

        expect(.COLON);
        _for.start_index = parse_expression();
        expect(.DOTDOT);
        _for.stop_index  = parse_expression();

        parent := peek(context.parser.block_stack);
        _for.block = parse_block(parent.block_type);
        _for.kind = .FOR;

        return _for;
    }

    if allow(.KEYWORD_switch) {
        switch := Make_Ast(Ast_Switch);
        switch.condition = parse_expression();

        parent := peek(context.parser.block_stack);
        expect(.OPEN_BRACE);

        while allow(.KEYWORD_case) {
            new := array_add(*switch.cases);
            new.compare = parse_expression();
            new.block = parse_block(parent.block_type);
        }

        expect(.CLOSED_BRACE);
        return switch;
    }

    if peek(.KEYWORD_sequential) {
        seq := parse_sequential_statement();
        return seq;
    }

    if peek(.KEYWORD_combinational) {
        comb := parse_combinational_statement();
        return comb;
    }

    if allow(.KEYWORD_jai) {
        braced := allow(.OPEN_BRACE);

        jai := Make_Ast(Ast_Jai_Code);
        expect(.JAI_CODE);

        jai.block_type = .STATIC;
        jai.code = current_token().string_value;

        if braced expect(.CLOSED_BRACE);
        else expect(.SEMICOLON);

        return jai;
    }

    using context.parser;
    parse_error("Wanted a statement but got token of kind %", stringify_token(tokens[token_index].kind));

    return null;
}

parse_lvalue :: (parsing_dot := false) -> *Ast_Node {
    if peek(.OPEN_BRACE) {
        return parse_concat();
    } else {
        ident_token := expect(.IDENTIFIER);

        ident := Make_Ast(Ast_Identifier);
        ident.name = ident_token.string_value;

        lhs: *Ast_Node;
        lhs = ident;

        if parsing_dot return lhs;

        while true {
            if peek(.OPEN_BRACKET) {
                lhs = parse_indexing_brackets(lhs);
            } else if allow(.OPERATOR_DOT) {
                op := Make_Ast(Ast_Binary_Op);
                op.operation = .OPERATOR_DOT;
                op.left = lhs;
                op.right = parse_lvalue(true);

                lhs = op;
            } else break;
        }

        return lhs;
    }
}

parse_assignment :: () -> *Ast_Assignment {
    lhs: *Ast_Node = parse_lvalue();

    op := expect(.EQUALS, .OPERATOR_LESS_OR_EQUAL);
    ass := Make_Ast(Ast_Assignment);

    if allow(.COMMA) {
        expect(.KEYWORD_trunc);
        ass.trunc = true;
    }

    ass.expr = parse_expression();
    ass.type = ifx op.kind == .EQUALS then .COMBINATIONAL else .SEQUENTIAL;
    ass.target = lhs;

    expect(.SEMICOLON);

    return ass;
}

parse_block :: (block_type: Block_Type) -> *Ast_Block {
    multi_line := allow(.OPEN_BRACE);

    block: *Ast_Block;

    if block_type == .MODULE {
        block = cast(*Ast_Block) Make_Ast(Ast_Module);
    } else {
        block = Make_Ast(Ast_Block);
    }

    block.block_type = block_type;

    statements: [..] *Ast_Node;

    push_block(block);

    while true {
        if multi_line if allow(.CLOSED_BRACE) break;

        s := parse_statement();
        if context.parser.error break;

        check_statement_allowed_in_block(s);
        if context.parser.error break;

        array_add(*statements, s);

        if !multi_line break;
    }

    pop_block();

    block.statements = statements;
    return block;
}

/* This feature is not in the language anymore but this code might be useful to reference later
#no_reset RUNTIME_DECLARATIONS :: #run read_entire_file("runtime_shared.jai");

generate_and_insert_ast :: (jai: *Ast_Jai_Code, statements: *[..] *Ast_Node, parent: *Ast_Block) {
    if !#compile_time return; // Todo

    #import "Compiler";
    ws := compiler_create_workspace(
        tprint("'Generate' block at line %", jai.location.line)
    );

    options := get_build_options(ws);
    options.output_type = .NO_OUTPUT;

    user_data := New(Generate_Block_User_Data);
    user_data.parent_block = parent;
    options.user_data_pointer = *user_data;
    options.user_data_pointer_size = size_of(**Generate_Block_User_Data);

    set_build_options(options, ws);

    compiler_begin_intercept(ws);

    the_program := tprint(JAI_CODE_FORMAT, RUNTIME_DECLARATIONS, jai.code);
    add_build_string(the_program, ws);

    while true {
        m := compiler_wait_for_message();
        if m.kind == .COMPLETE break;

        if m.kind == .ERROR {
            parse_error("There has been a Jai execution or compilation failure");
            return;
        }
    }

    for 0..user_data.num_emitted-1 {
        array_add(statements, user_data.syntax_trees[it]);
    }

    compiler_end_intercept(ws);
}

JAI_CODE_FORMAT :: #string END
#import "Basic";
#import "Compiler";

%1 // The Ast_* and Datatype struct definitions

user_data: *Generate_Block_User_Data;

valent_emit_ast :: (ast: *Ast_Node) {
    user_data.syntax_trees[user_data.num_emitted] = ast;
    user_data.num_emitted += 1;
}

valent_get_parent_block :: () -> *Ast_Block {
    return user_data.parent_block;
}

#run {
    {
        options := get_build_options();
        user_data = << cast(**Generate_Block_User_Data) options.user_data_pointer;
    }

    %2; // The user program
}
END;
*/

parse_declaration :: () -> *Ast_Declaration {
    ident := expect(.IDENTIFIER);

    decl := Make_Ast(Ast_Declaration);
    decl.name = ident.string_value;

    allow(.COLON);
    decl.constant = allow(.COLON);

    decl.datatype.is_type = peek_type();
    decl.expression = parse_expression();

    return decl;
}

parse_expression :: (precedence := -1) -> *Ast_Node {
    left := parse_factor();

    while true {
        next := peek();

        is_binop := next > ._BEGIN_OPERATORS && next < ._END_OPERATORS;
        if !is_binop break;

        next_precedence := get_operator_info(next).precedence;
        if next_precedence <= precedence break;

        allow(next);
        op := Make_Ast(Ast_Binary_Op);

        right := parse_expression(next_precedence);

        op.operation = next;
        op.left = left;
        op.right = right;

        left = op;
    }

    return left;
}

parse_factor :: () -> *Ast_Node {

    if allow(.EXCLAMATION_MARK, .TILDE) {
        op := Make_Ast(Ast_Unary_Op);
        op.operation = ifx current_token().kind == .EXCLAMATION_MARK then .LOGIC_NOT else .BIT_NOT;

        op.argument = parse_factor();

        return op;
    }

    return parse_atom();
}

parse_atom :: () -> *Ast_Node {
    atom: *Ast_Node;

    if allow(.IDENTIFIER) {
        ident := Make_Ast(Ast_Identifier);
        ident.name = current_token().string_value;

        if peek(.OPEN_PAREN) {
            module := Make_Ast(Ast_Module_Inst);
            module.ident = ident;

            expect(.OPEN_PAREN);

            while allow(.IDENTIFIER) {
                ident := array_add(*module.inputs);
                ident.*.name = current_token().string_value;
                ident.*.location = current_token().location;
                if !allow(.COMMA) break;
            }

            expect(.CLOSED_PAREN);

            if allow(.ARROW) {
                started_with_paren := allow(.OPEN_PAREN);

                while allow(.IDENTIFIER) {
                    ident := array_add(*module.outputs);
                    ident.*.name = current_token().string_value;
                    ident.*.location = current_token().location;
                    if !allow(.COMMA) break;
                }

                if started_with_paren {
                    expect(.CLOSED_PAREN);
                }
            }

            return module;
        }

        atom = ident;
    }

    else if allow(.INTEGER) {
        lit := Make_Ast(Ast_Literal);
        // lit.type = *primitive_types[Datatype.Primitive.CONSTANT];
        lit.int_value = current_token().int_value;
        lit.bit_width = current_token().bit_width;

        atom = lit;
    }

//    if allow(.STRING) {
//        lit := Make_Ast(Ast_Literal);
//        // lit.type = *primitive_types[Datatype.Primitive.STRING];
//        lit.string_value = current_token().string_value;
//
//        atom = lit;
//    }

    else if peek(.KEYWORD_module) {
        atom = parse_module();
    }

    else if peek(.KEYWORD_enum) {
        atom = parse_enum();
    }

    else if peek(.KEYWORD_register) {
        atom = parse_register();
    }

    else if peek(.OPEN_BRACE) {
        atom = parse_concat();
    }

    else if allow(.OPEN_PAREN) {
        atom = parse_expression();
        expect(.CLOSED_PAREN);
    }

    else if peek(.OPEN_BRACKET) {
        return parse_memory();
    }

    if !atom {
        using context.parser;
        parse_error("Expected an expression, got token %", stringify_token(tokens[token_index].kind));

        return null;
    }

    while peek(.OPEN_BRACKET) {
        atom = parse_indexing_brackets(atom);
    }

    return atom;
}

parse_indexing_brackets :: (left: *Ast_Node) -> *Ast_Binary_Op {
    expect(.OPEN_BRACKET);

    op := Make_Ast(Ast_Binary_Op);
    op.operation = .OPEN_BRACKET;
    op.left = left;
    op.right = parse_expression();

    if allow(.COLON, .POSITIVE_SELECT, .NEGATIVE_SELECT) {
        sel := Make_Ast(Ast_Bit_Select);

        if current_token().kind == {
            case .POSITIVE_SELECT; sel.select_type = .POSITIVE_FIXED_WIDTH;
            case .NEGATIVE_SELECT; sel.select_type = .NEGATIVE_FIXED_WIDTH;
            case .COLON;           sel.select_type = .RANGE;
            case; assert(false);
        }

        sel.left = op.right;
        op.right = sel;
        sel.right = parse_expression();
    }

    expect(.CLOSED_BRACKET);

    return op;
}

parse_memory :: () -> *Ast_Memory {
    expect(.OPEN_BRACKET);
    depth := parse_expression();
    expect(.CLOSED_BRACKET);

    expect(.KEYWORD_memory);
    memory := Make_Ast(Ast_Memory);
    memory.depth_expression = depth;

    expect(.OPEN_BRACKET);
    memory.width_expression = parse_expression();
    expect(.CLOSED_BRACKET);

    return memory;
}

parse_enum :: () -> *Ast_Enum {
    expect(.KEYWORD_enum);
    _enum := Make_Ast(Ast_Enum);

    if allow(.OPEN_BRACKET) {
        _enum.width = parse_expression();
        expect(.CLOSED_BRACKET);
    }

    expect(.OPEN_BRACE);

    fields: [..] Ast_Enum.Field;

    while peek(.IDENTIFIER) {
        new := array_add(*fields);
        new.name = expect(.IDENTIFIER).string_value;

        if allow(.COLON) {
            expect(.COLON);
            new.value_expr = parse_expression();
        }

        expect(.SEMICOLON);
    }

    expect(.CLOSED_BRACE);

    _enum.fields = fields;
    return _enum;
}

parse_register :: () -> *Ast_Register {
    expect(.KEYWORD_register);
    register := Make_Ast(Ast_Register);

    if allow(.OPEN_BRACKET) {
        register.width_expr = parse_expression();
        expect(.CLOSED_BRACKET);
    }

    expect(.OPEN_BRACE);

    fields: [..] Ast_Register.Field;

    while peek(.IDENTIFIER) {
        new := array_add(*fields);
        new.name = expect(.IDENTIFIER).string_value;

        if allow(.OPEN_BRACKET) {
            new.width_expr = parse_expression();
            expect(.CLOSED_BRACKET);
        }

        expect(.SEMICOLON);
    }

    expect(.CLOSED_BRACE);
    register.fields = fields;
    return register;
}

parse_concat :: () -> *Ast_Concat {
    cat := Make_Ast(Ast_Concat);

    expect(.OPEN_BRACE);
    fields: [..] *Ast_Node;

    first := parse_expression();
    array_add(*fields, first);

    while allow(.COMMA) {
        expr := parse_expression();
        array_add(*fields, expr);
    }

    cat.fields = fields;
    expect(.CLOSED_BRACE);

    return cat;
}

parse_module :: () -> *Ast_Module {
    expect(.KEYWORD_module);

    constants, inputs, outputs := parse_parameter_list();

    module := cast(*Ast_Module) parse_block(.MODULE);

    module.constant_parameters = constants;
    module.inputs = inputs;
    module.outputs = outputs;

    return module;
}

parse_sequential_statement :: () -> *Ast_Sequential_Circuit {
    expect(.KEYWORD_sequential);
    seq := Make_Ast(Ast_Sequential_Circuit);

    expect(.OPEN_PAREN);

    sensitivity := parse_expression();
    assert(sensitivity.kind == .IDENTIFIER);

    expect(.CLOSED_PAREN);

    seq.clock = cast(*Ast_Identifier) sensitivity;
    seq.block = parse_block(.SEQUENTIAL);

    return seq;
}

parse_combinational_statement :: () -> *Ast_Combinational_Circuit {
    expect(.KEYWORD_combinational);

    comb := Make_Ast(Ast_Combinational_Circuit);
    comb.block = parse_block(.COMBINATIONAL);

    return comb;
}

parse_parameter_list :: () -> [] *Ast_Declaration, [] *Ast_Declaration, [] *Ast_Declaration {
    constants: [..] *Ast_Declaration;
    inputs: [..] *Ast_Declaration;
    outputs: [..] *Ast_Declaration;

    started_with_paren := allow(.OPEN_PAREN);

    while peek(.IDENTIFIER) {
        decl := parse_declaration();
        decl.module_input = true;
        array_add(*inputs, decl);

        if !allow(.COMMA) break;
    }

    if started_with_paren {
        expect(.CLOSED_PAREN);
    }

    if allow(.ARROW) {
        started_with_paren := allow(.OPEN_PAREN);

        decl := parse_declaration();
        array_add(*outputs, decl);

        if allow(.COMMA) while peek(.IDENTIFIER) {
            decl := parse_declaration();
            array_add(*outputs, decl);

            if !allow(.COMMA) break;
        }

        if started_with_paren {
            expect(.CLOSED_PAREN);
        }
    }

    return constants, inputs, outputs;
}

peek_type :: () -> bool {
    if peek(.KEYWORD_enum) return true;
    if peek(.KEYWORD_module) return true;
    if peek(.KEYWORD_register) return true;

    if peek(.IDENTIFIER) {
        using context.parser;
        id := tokens[token_index].string_value;
        return id == "flipflop" || id == "wire";
    }

    return false;
}


allow :: (allowed: .. Token_Kind) -> bool {
    using context.parser;
    new := tokens[token_index];

    for allowed if new.kind == it {
        token_index += 1;
        return true;
    }

    return false;
}

expect :: (expected: .. Token_Kind) -> Token {
    using context.parser;
    new := tokens[token_index];
    token_index += 1;

    for expected if new.kind == it return new;

    if !error {
        error = true;
        error_location = tokens[token_index-1].location;
        wanted = array_copy(expected);
        got = new.kind;
    }

    return new;
}

parse_error :: (report: string, format: .. Any) {
    using context.parser;

    if !error {
        error = true;
        custom_report = tprint(report, .. format);
        error_location = tokens[token_index].location;
    }
}

peek :: () -> Token_Kind {
    using context.parser;

    if token_index >= tokens.count {
        return .EOT;
    }

    return tokens[token_index].kind;
}

peek :: (expected: .. Token_Kind, distance := 1) -> bool {
    using context.parser;

    if token_index + distance - 1 >= tokens.count {
        for expected if it == .EOT {
            return true;
        }

        return false;
    }

    for expected {
        if it == tokens[token_index + distance - 1].kind {
            return true;
        }
    }

    return false;
}

current_token :: () -> Token {
    using context.parser;

    if token_index == 0 return .{};

    return tokens[token_index - 1]; // The last token that was allowed or expected
}

Token :: struct {
    kind: Token_Kind;

    int_value: int;
    bit_width: int;

    string_value: string;

    using location: Source_Location;
}

EOT : u8 : 0x4;

Tokenizer :: struct {
    cursor: int;
    source: string;

    last_line_start: int = -1;
    line: int;
}

tokenize :: (source: string) -> [] Token {
    output_token_stream: [..] Token;

    tokenizer: Tokenizer;
    tokenizer.source = source;

    context.parser.source_code_lines = split(source, "\n");

    array_reserve(*output_token_stream, source.count / 4);

    while true {
        token := get_next_token(*tokenizer);
        array_add(*output_token_stream, token);

        if token.kind == .ERROR break;
        if token.kind == .EOT   break;

        if token.kind == .KEYWORD_jai {

            starts_with_brace := peek_token(*tokenizer).kind == .OPEN_BRACE;
            if starts_with_brace {
                array_add(*output_token_stream, get_next_token(*tokenizer));
            }

            Jai :: #import "Jai_Lexer";

            lexer: Jai.Lexer;
            lexer_input: string;
            lexer_input.data = source.data + tokenizer.cursor;
            lexer_input.count = source.count - tokenizer.cursor;

            Jai.set_input_from_string(*lexer, lexer_input);
            brace_level: int;

            while true {
                token := Jai.peek_next_token(*lexer);

                if token.type == {
                    case #char "{"; brace_level += 1;
                    case #char "}"; brace_level -= 1;
                    case .END_OF_INPUT; assert(false); // Todo
                    case .ERROR; assert(false); // Todo
                    case #char ";"; if !starts_with_brace && brace_level == 0 {
                        Jai.eat_token(*lexer);
                        break;
                    }
                }

                if brace_level < 0 break;

                Jai.eat_token(*lexer);
            }

            jai_code := lexer_input;
            jai_code.count = lexer.input_cursor-1;

            jai_code_token: Token;
            jai_code_token.kind = .JAI_CODE;
            jai_code_token.string_value = jai_code;
            // Todo fixup source location
            array_add(*output_token_stream, jai_code_token);

            // Todo fixup line numbers
            tokenizer.cursor += jai_code.count;
        }
    }

    return output_token_stream;
}

peek_token :: (tokenizer: *Tokenizer) -> Token {
    old_state := tokenizer.*;
    peeked := get_next_token(tokenizer);
    tokenizer.* = old_state;
    return peeked;
}

get_next_token :: (using tokenizer: *Tokenizer) -> Token {

    current :: () -> u8 #expand {
        if cursor >= source.count  return EOT;
        return source[cursor];
    }

    result: Token;

    Emit :: (kind: Token_Kind) -> *Token #expand {
        token := *result;
        token.kind = kind;

        token.line = line;
        token.start_char = start - last_line_start - 1;
        token.end_char = cursor - last_line_start;

        return token;
    }

    is_char :: (char: u8) -> bool {
        if char >= #char "a" && char <= #char "z"  return true;
        if char >= #char "A" && char <= #char "Z"  return true;
        if char == #char "_"  return true;
        return false;
    }

    is_num :: (char: u8) -> bool {
        if char >= #char "0" && char <= #char "9"  return true;
        return false;
    }

    while current() == #char " " || current() == #char "\r" || current() == #char "\n" {
        if current() == #char "\n"  {
            last_line_start = cursor;
            line += 1;
        }
        cursor += 1;
    }

    start := cursor;

    if current() == {
      case #char ","; Emit(.COMMA);
      case #char ";"; Emit(.SEMICOLON);
      case #char "#"; Emit(.OPERATOR_REPEAT);
      case #char "*"; Emit(.OPERATOR_MULTIPLY);
      case #char "("; Emit(.OPEN_PAREN);
      case #char ")"; Emit(.CLOSED_PAREN);
      case #char "["; Emit(.OPEN_BRACKET);
      case #char "]"; Emit(.CLOSED_BRACKET);
      case #char "{"; Emit(.OPEN_BRACE);
      case #char "}"; Emit(.CLOSED_BRACE);
      case #char "%"; Emit(.OPERATOR_MODULO);
      case #char "^"; Emit(.OPERATOR_BIT_XOR);
      case #char "~"; Emit(.TILDE);
      case #char ":"; Emit(.COLON);
      // case #char "'"; Emit(.OPERATOR_WIDTH);

      case #char "|";
        cursor += 1;
        if current() == #char "|"  Emit(.OPERATOR_LOGICAL_OR);
        else {
            cursor -= 1;
            Emit(.OPERATOR_BIT_OR);
        }

      case #char ".";
        cursor += 1;
        if current() == #char "."  Emit(.DOTDOT);
        else {
            cursor -= 1;
            Emit(.OPERATOR_DOT);
        }

      case #char "+";
        cursor += 1;
        if current() == #char ":"  Emit(.POSITIVE_SELECT);
        else {
            cursor -= 1;
            Emit(.OPERATOR_ADD);
        }

      case #char "!";
        cursor += 1;
        if current() == #char "="  Emit(.OPERATOR_NOT_EQUAL);
        else {
            cursor -= 1;
            Emit(.EXCLAMATION_MARK);
        }

      case #char "&";
        cursor += 1;
        if current() == #char "&"  Emit(.OPERATOR_LOGICAL_AND);
        else {
            cursor -= 1;
            Emit(.OPERATOR_BIT_AND);
        }

      case #char "-";
        cursor += 1;
        if      current() == #char ">"  Emit(.ARROW);
        else if current() == #char ":"  Emit(.NEGATIVE_SELECT);
        else {
            cursor -= 1;
            Emit(.OPERATOR_SUBTRACT);
        }

      case #char "=";
        cursor += 1;
        if current() == #char "="  Emit(.OPERATOR_EQUALS);
        else {
            cursor -= 1;
            Emit(.EQUALS);
        }

      case #char ">";
        cursor += 1;
        if current() == #char "="  Emit(.OPERATOR_GREATER_OR_EQUAL);
        else if current() == #char ">" {
            cursor += 1;
            if current() == #char ">" Emit(.OPERATOR_SHIFT_RIGHT_ARITH);
            else {
                cursor -= 1;
                Emit(.OPERATOR_SHIFT_RIGHT);
            }
        } else {
            cursor -= 1;
            Emit(.OPERATOR_GREATER_THAN);
        }

      case #char "<";
        cursor += 1;
        if      current() == #char "="  Emit(.OPERATOR_LESS_OR_EQUAL);
        else if current() == #char "<" {
            cursor += 1;
            if current() == #char "<" Emit(.OPERATOR_SHIFT_LEFT_ARITH);
            else {
                cursor -= 1;
                Emit(.OPERATOR_SHIFT_LEFT);
            }
        } else {
            cursor -= 1;
            Emit(.OPERATOR_LESS_THAN);
        }

      case #char "/";
        cursor += 1;
        if current() == #char "/" {
            while current() != #char "\n" && current() != EOT cursor += 1;
            return get_next_token(tokenizer);
        } else if current() == #char "*" {
            while true {
                if current() == EOT Emit(.ERROR);
                if current() == #char "/" && source[cursor-1] == #char "*" break;
                if current() == #char "\n" line += 1;
                cursor += 1;
            }

            return get_next_token(tokenizer);
        } else {
            cursor -= 1;
            Emit(.OPERATOR_DIVIDE);
        }

      case 0; #through;
      case EOT;
        Emit(.EOT);

      case;
        if is_num(current()) || current() == #char "'" {

            width := -1;
            base := 10;

            start: int;
            end: int;

            if is_num(current()) {
                start = cursor;
                while is_num(current()) {
                    cursor += 1;
                }
                end = cursor;
            }

            if current() == #char "'" {

                if end {
                    width_str: string;
                    width_str.data = source.data + start;
                    width_str.count = end - start;

                    success: bool;
                    width, success = string_to_int(width_str);

                    assert(success);

                }

                cursor += 1;
                if current() == {
                  case #char "d";
                  case #char "h"; base = 16;
                  case #char "b"; base = 2;
                  case; Emit(.ERROR);  
                }

                cursor += 1;
                
                if is_num(current()) || is_char(current()) {
                    start = cursor;
                    while is_num(current()) || is_char(current()) {
                        cursor += 1;
                    }
                    end = cursor;
                }
            }

            cursor -= 1;

            value_str: string;
            value_str.data = source.data + start;
            value_str.count = end - start;
            value, success := string_to_int(value_str, base = base);

            assert(success, tprint("string_to_int failed with string '%'", value_str));

            lit := Emit(.INTEGER);
            lit.int_value = value;
            lit.bit_width = width;
        }

        else if is_char(current()) {
            ident: string;
            ident.data = source.data + cursor;
            while is_char(current()) || is_num(current()) {
                ident.count += 1;
                cursor += 1;
            }
            cursor -= 1;

            keyword := lookup_keyword(ident);

            if keyword != .INVALID Emit(keyword);
            else {
                id := Emit(.IDENTIFIER);
                id.string_value = ident;
            }
        }

        else {
            Emit(.ERROR);
        }
    }

    cursor += 1;
    return result;
}

stringify_token :: (token: Token_Kind) -> string {
    if token == {
      case .COLON;                 return "Colon (:)";
      case .OPERATOR_DOT;          return "Dot (.)";
      case .OPERATOR_SUBTRACT;     return "Minus (-)";
      case .OPERATOR_ADD;          return "Plus (+)";
      case .OPERATOR_MULTIPLY;     return "Asterisk (*)";
      case .OPERATOR_DIVIDE;       return "Slash (/)";
      case .OPERATOR_WIDTH;        return "Apostrophe (')";
      case .COMMA;                 return "Comma (,)";
      case .OPERATOR_BIT_OR;       return "Vertical Bar (|)";
      case .SEMICOLON;             return "Semicolon (;)";
      case .EQUALS;                return "Equals (=)";
      case .EXCLAMATION_MARK;      return "Exclamation Mark (!)";
      case .OPERATOR_LESS_THAN;    return "Less Than (<)";
      case .OPERATOR_GREATER_THAN; return "Greater Than (>)";
      case .OPEN_PAREN;            return "Open Parenthesis (()";
      case .CLOSED_PAREN;          return "Closed Parenthesis ())";
      case .OPEN_BRACKET;          return "Open Bracket ([)";
      case .CLOSED_BRACKET;        return "Closed Bracket (])";
      case .OPEN_BRACE;            return "Open Brace ({)";
      case .CLOSED_BRACE;          return "Closed Brace (})";
      case .OPERATOR_EQUALS;       return "Double Equals (==)";
      case .OPERATOR_LOGICAL_OR;   return "Logical Or (||)";
      case .ARROW;                 return "Arrow (->)";
      case .DOTDOT;                return "Dot Dot (..)";
      case .OPERATOR_REPEAT;       return "Pound (#)";
      case .IDENTIFIER;            return "Identifier";
      case .INTEGER;               return "Integer";
      case .KEYWORD_module;        return "Keyword 'module'";
      case .KEYWORD_register;      return "Keyword 'register'";
      case .KEYWORD_enum;          return "Keyword 'enum'";
      case .KEYWORD_memory;        return "Keyword 'memory'";
      case .KEYWORD_combinational; return "Keyword 'combinational'";
      case .KEYWORD_sequential;    return "Keyword 'sequential'";
      case .KEYWORD_using;         return "Keyword 'using'";
      case .KEYWORD_for;           return "Keyword 'for'";
      case .KEYWORD_if;            return "Keyword 'if'";
      case .KEYWORD_else;          return "Keyword 'else'";
      case .KEYWORD_jai;           return "Keyword 'jai'";
      case .KEYWORD_switch;        return "Keyword 'switch'";
      case .KEYWORD_case;          return "Keyword 'case'";
      case .KEYWORD_trunc;         return "Keyword 'trunc'";
      case .JAI_CODE;              return "Jai Code";
      case .ERROR;                 return "(Unrecognised token)";
      case .EOT;                   return "End Of Text";
      case .INVALID;               return "(Unrecognised token)";

      case;
        assert(false, tprint("Tried to stringify token %\n", token));
        return tprint("%", token);
    }
}

lookup_keyword :: (ident: string) -> Token_Kind {
    ti := type_info(Token_Kind);

    for Token_Kind._BEGIN_KEYWORDS+1 .. Token_Kind._END_KEYWORDS-1 {
        name := ti.names[it];
        name.data += "KEYWORD_".count;
        name.count -= "KEYWORD_".count;

        if name == ident return cast(Token_Kind) it;
    }

    return .INVALID;
}

// Copied from Basic except it skips underscores
string_to_int :: (t: string, base := 10, $T := int) -> result: T, success: bool, remainder: string {
    //
    // This string_to_int might be a little slower than max speed because we multiply by 'sign' for
    // each digit. Our original approach did not do this, but rather we just accumulated into a
    // positive value and then negated at the end if we saw a -. But this does not let us parse the
    // maximum negative number without overflowing the positive number, which works, *if* you are
    // not doing arithmetic bounds checks. We could have done #no_abc on this procedure, but
    // I decided it's worthwhile to just try to preserve the ability to report genuine overflows,
    // so I did 'the clean version' here.    -jblow, 4 July 2023
    //
    assert(base == 16 || base <= 10);
    
    s := eat_spaces(t);

    if !s return 0, false, "";

    sign : T = 1;
    
    #if #run type_info(T).signed {
        if s[0] == #char "-" {
            sign = -1;
            advance(*s, 1);
            s = eat_spaces(s);
        } else if s[0] == #char "+" {
            advance(*s, 1);
            s = eat_spaces(s);
        }
    }

    sum: T = 0;
    cursor := 0;

    // @Incomplete: We should probably check for overflows…
    if base == 16 {
        while cursor < s.count {
            c := s[cursor];

            if c == #char "_" {
                cursor += 1;
                continue;
            }

            value: u8 = ---;
            if is_digit(c) {
                value = c - #char "0";
            } else if (c >= #char "a") && (c <= #char "f") {
                value = c - #char "a" + 10;
            } else if (c >= #char "A") && (c <= #char "F") {
                value = c - #char "A" + 10;
            } else {
                break;
            }

            sum *= cast(T) base;
            sum += sign*value;

            cursor += 1;
        }
    } else {
        while cursor < s.count {
            c := s[cursor];

            if c == #char "_" {
                cursor += 1;
                continue;
            }

            if !is_digit(c) break;

            digit := c - #char "0";
            if digit >= base break;

            sum *= cast(T) base;
            sum += sign*digit;

            cursor += 1;
        }
    }

    success := (cursor != 0);
    advance(*s, cursor);

    return sum, success, s;
}
