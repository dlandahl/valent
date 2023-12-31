
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

Ast_Node :: struct {

    Kind :: enum {
        NONE;
        DECLARATION;
        IDENTIFIER;
        BINARY_OP;
        UNARY_OP;
        LITERAL;
        CHIP;
        SEQUENTIAL_CIRCUIT;
        COMBINATIONAL_CIRCUIT;
        ASSIGNMENT;
        IF;
        BLOCK;
        BIT_SELECT;
        CONCAT;
    }

    kind: Kind;
    location: Source_Location;

    datatype: Datatype;
    typechecked: bool;
}

Ast_Declaration :: struct {
    using #as node: Ast_Node;
    node.kind = .DECLARATION;

    name: string;
    type_expression: *Ast_Node;
    initialisation_value: *Ast_Node;

    constant: bool;
}

Ast_Concat :: struct {
    using #as node: Ast_Node;
    node.kind = .CONCAT;

    fields: [] *Ast_Node;
}

Ast_Block :: struct {
    using #as node: Ast_Node;
    node.kind = .BLOCK;

    statements: [] *Ast_Node;
    parent: *Ast_Block;
    block_type: Block_Type;
}

Ast_Identifier :: struct {
    using #as node: Ast_Node;
    node.kind = .IDENTIFIER;

    name: string;
    resolved_declaration: *Ast_Declaration;
}

Ast_Literal :: struct {
    using #as node: Ast_Node;
    node.kind = .LITERAL;

    int_value: int;
    bit_width: int;
}

Ast_Assignment :: struct {
    using #as node: Ast_Node;
    node.kind = .ASSIGNMENT;

    target: *Ast_Identifier;
    expr: *Ast_Node;

    type: enum {
        SEQUENTIAL;
        COMBINATIONAL;
    }
}

Ast_If :: struct {
    using #as node: Ast_Node;
    node.kind = .IF;

    condition: *Ast_Node;
    block: *Ast_Block;
    else_block: *Ast_Block;
}

Ast_Binary_Op :: struct {
    using #as node: Ast_Node;
    node.kind = .BINARY_OP;

    left: *Ast_Node;
    right: *Ast_Node;

    operation: Token_Kind;
}

Ast_Unary_Op :: struct {
    using #as node: Ast_Node;
    node.kind = .UNARY_OP;

    argument: *Ast_Node;

    operation: enum {
        LOGIC_NOT;
        BIT_NOT;
    }
}

Ast_Chip :: struct {
    using #as body: Ast_Block;
    node.kind = .CHIP;

    constant_parameters: [] *Ast_Declaration;
    inputs: [] *Ast_Declaration;
    outputs: [] *Ast_Declaration;
}

Ast_Sequential_Circuit :: struct {
    using #as node: Ast_Node;
    node.kind = .SEQUENTIAL_CIRCUIT;

    clock: *Ast_Identifier;
    block: *Ast_Block;
}

Ast_Combinational_Circuit :: struct {
    using #as node: Ast_Node;
    node.kind = .COMBINATIONAL_CIRCUIT;

    block: *Ast_Block;
}

Ast_Bit_Select :: struct {
    using #as node: Ast_Node;
    node.kind = .BIT_SELECT;

    left: *Ast_Node;
    right: *Ast_Node;

    select_type: enum {
        RANGE;
        POSITIVE_FIXED_WIDTH;
        NEGATIVE_FIXED_WIDTH;
    };
}



Block_Type :: enum {
    NONE;
    TOP_LEVEL;
    CHIP;
    SEQUENTIAL;
    COMBINATIONAL;
    _COUNT;
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

        if block_type == {
          case .TOP_LEVEL;
            if ast.kind != .DECLARATION {
                return false, "Expected a declaration at top level";
            }

            decl := cast(*Ast_Declaration) ast;
            if !decl.constant {
                return false, "Non-constant declaration at top level";
            }

          case .CHIP;
          case .SEQUENTIAL;
            if ast.kind == .IF return true, "";
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

      case .ASSIGNMENT;
        ass := cast(*Ast_Assignment) ast;
        if ass.type == .COMBINATIONAL return "Combinational Assignment";
        return "Sequential Assignment";
    }

    assert(false);
    return "";
}

operator_info :: Binary_Operator_Info.[
    .{ .OPERATOR_ADD,              "+",  "$add",       10 },
    .{ .OPERATOR_SUBTRACT,         "-",  "$sub",       10 },
    .{ .OPERATOR_MULTIPLY,         "*","  $mul",       11 },
    .{ .OPERATOR_DIVIDE,           "/",  "$div",       11 },
    .{ .OPERATOR_MODULO,           "%",  "$mod",       11 },
    .{ .OPERATOR_BIT_OR,           "|",  "$or",        3  },
    .{ .OPERATOR_BIT_AND,          "&",  "$and",       5  },
    .{ .OPERATOR_BIT_XOR,          "^",  "$xor",       7  },
    .{ .OPERATOR_LESS_THAN,        "<",  "$lt",        8  },
    .{ .OPERATOR_GREATER_OR_EQUAL, ">=", "$ge",        8  },
    .{ .OPERATOR_LESS_OR_EQUAL,    "<=", "$le",        8  },
    .{ .OPERATOR_GREATER_THAN,     ">",  "$gt",        8  },
    .{ .OPERATOR_EQUALS,           "==", "$eq",        6  },
    .{ .OPERATOR_NOT_EQUAL,        "!=", "$ne",        6  },
    .{ .OPERATOR_LOGICAL_OR,       "||", "$logic_or",  1  },
    .{ .OPERATOR_LOGICAL_AND,      "&&", "$logic_and", 2  },
    .{ .OPERATOR_SHIFT_LEFT,       "<<", "$shl",       9  },
    .{ .OPERATOR_SHIFT_RIGHT,      ">>", "$shr",       9  },
];

Binary_Operator_Info :: struct {
    token: Token_Kind;
    verilog_string: string;
    rtlil_cell_type: string;
    precedence: int;
}

get_operator_info :: (token: Token_Kind) -> *Binary_Operator_Info {
    for *operator_info if it.token == token return it;

    assert(false);
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
                print("Parse error! %.\n", parser.custom_report);
            } else {
                print("Parse error! Wanted %, got %.\n", stringify_token(parser.wanted[0]), stringify_token(parser.got));
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

            print("\nline %:%[31m%[0m%\n", loc.line, first, second, third);

            return top_level;
        }
    }

    pop_block();
    return top_level;
}

parse_statement :: () -> *Ast_Node {

    if peek(.IDENTIFIER) {
        if peek(.COLON, .DOUBLE_COLON, distance = 2) {
            decl := parse_declaration();

            if current_token().kind != .CLOSED_BRACE {
                expect(.SEMICOLON);
            }

            return decl;
        }


        if peek(.EQUALS, .OPERATOR_LESS_OR_EQUAL, distance = 2) {
            ident := expect(.IDENTIFIER);
            op := expect(.EQUALS, .OPERATOR_LESS_OR_EQUAL);

            ass := Make_Ast(Ast_Assignment);

            ass.target = Make_Ast(Ast_Identifier);
            ass.target.name = ident.string_value;
            ass.target.location = ident.location;

            ass.expr = parse_expression();
            ass.type = ifx op.kind == .EQUALS then .COMBINATIONAL else .SEQUENTIAL;

            expect(.SEMICOLON);

            return ass;
        }

        using context.parser;
        parse_error("Expected this identifier to be an assignment or a declaration, but it was followed by a token of kind %", stringify_token(tokens[token_index+1].kind));

        return null;
    }

    if allow(.KEYWORD_if) {
        _if := Make_Ast(Ast_If);
        _if.condition = parse_expression();

        // An If statement inherits the block type it's in
        parent := peek(context.parser.block_stack);
        _if.block = parse_block(parent.block_type);

        if allow(.KEYWORD_else) {
            _if.else_block = parse_block(parent.block_type);
        }

        return _if;
    }

    if peek(.KEYWORD_sequential) {
        seq := parse_sequential_statement();
        return seq;
    }

    if peek(.KEYWORD_combinational) {
        comb := parse_combinational_statement();
        return comb;
    }

    using context.parser;
    parse_error("Wanted a statement but got token of kind %", stringify_token(tokens[token_index].kind));

    return null;
}

parse_block :: (block_type: Block_Type) -> *Ast_Block {
    multi_line := allow(.OPEN_BRACE);

    block: *Ast_Block;

    if block_type == .CHIP {
        block = cast(*Ast_Block) Make_Ast(Ast_Chip);
    } else {
        block = Make_Ast(Ast_Block);
    }

    block.block_type = block_type;

    statements: [..] *Ast_Node;

    push_block(block);

    while true {
        if multi_line if allow(.CLOSED_BRACE) break;

        statement := parse_statement();
        if context.parser.error break;

        check_statement_allowed_in_block(statement);
        if context.parser.error break;

        array_add(*statements, statement);

        if !multi_line break;
    }

    pop_block();

    block.statements = statements;
    return block;
}

parse_declaration :: () -> *Ast_Declaration {
    ident := expect(.IDENTIFIER);

    decl := Make_Ast(Ast_Declaration);
    decl.name = ident.string_value;

    if allow(.DOUBLE_COLON) {
        decl.initialisation_value = parse_expression();
        decl.constant = true;
    } else if allow(.COLON) {
        decl.type_expression = parse_expression();
        decl.constant = false;
    }

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

    else if peek(.KEYWORD_chip) {
        atom = parse_chip();
    }

    else if peek(.OPEN_BRACE) {
        atom = parse_concat();
    }

    else if allow(.OPEN_PAREN) {
        atom = parse_expression();
        expect(.CLOSED_PAREN);
    }

    if !atom {
        using context.parser;
        parse_error("Expected an expression, got token %", stringify_token(tokens[token_index].kind));

        return null;
    }

    while allow(.OPEN_BRACKET) {
        op := Make_Ast(Ast_Binary_Op);
        op.operation = .OPEN_BRACKET; // Eh...
        op.left = atom;
        op.right = parse_expression();

        if allow(.COLON) {
            sel := Make_Ast(Ast_Bit_Select);
            sel.left = op.right;
            op.right = sel;
            sel.right = parse_expression();
        }

        expect(.CLOSED_BRACKET);

        atom = op;
    }

    return atom;
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

parse_chip :: () -> *Ast_Chip {
    expect(.KEYWORD_chip);

    constants, inputs, outputs := parse_parameter_list();

    chip := cast(*Ast_Chip) parse_block(.CHIP);

    chip.constant_parameters = constants;
    chip.inputs = inputs;
    chip.outputs = outputs;

    return chip;
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
    started_with_paren := allow(.OPEN_PAREN);

    constants: [..] *Ast_Declaration;
    inputs: [..] *Ast_Declaration;
    outputs: [..] *Ast_Declaration;

    while peek(.IDENTIFIER) {
        decl := parse_declaration();
        array_add(*inputs, decl);

        if !allow(.COMMA) break;
    }

    if allow(.OPERATOR_BIT_OR) {
        constants = inputs;

        inputs.data = null;
        inputs.allocated = 0;
        inputs.count = 0;

        while peek(.IDENTIFIER) {
            decl := parse_declaration();
            array_add(*inputs, decl);

            if !allow(.COMMA) break;
        }
    }

    if started_with_paren {
        expect(.CLOSED_PAREN);
    }

    if allow(.ARROW) {
        started_with_paren := allow(.OPEN_PAREN);

        decl := parse_declaration();
        array_add(*outputs, decl);

        while peek(.IDENTIFIER) {
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
        wanted = array_copy(expected);
        got = new.kind;
        assert(false);
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



Token_Kind :: enum {
    INVALID;

    _BEGIN_OPERATORS;
    OPERATOR_ADD;
    OPERATOR_SUBTRACT;
    OPERATOR_MULTIPLY;
    OPERATOR_DIVIDE;
    OPERATOR_MODULO;
    OPERATOR_BIT_OR;
    OPERATOR_BIT_AND;
    OPERATOR_BIT_XOR;
    OPERATOR_LESS_THAN;
    OPERATOR_GREATER_OR_EQUAL;
    OPERATOR_LESS_OR_EQUAL;
    OPERATOR_GREATER_THAN;
    OPERATOR_EQUALS;
    OPERATOR_NOT_EQUAL;
    OPERATOR_LOGICAL_OR;
    OPERATOR_LOGICAL_AND;
    OPERATOR_SHIFT_LEFT;
    OPERATOR_SHIFT_RIGHT;
    _END_OPERATORS;

    COLON;
    COMMA;
    SEMICOLON;
    DOT;
    EQUALS;
    EXCLAMATION_MARK;
    TILDE;
    OPEN_PAREN;
    CLOSED_PAREN;
    OPEN_BRACKET;
    CLOSED_BRACKET;
    OPEN_BRACE;
    CLOSED_BRACE;

    ARROW;
    DOUBLE_COLON;

    IDENTIFIER;
    INTEGER;

    _BEGIN_KEYWORDS;
    KEYWORD_chip;
    KEYWORD_function;
    KEYWORD_struct;
    KEYWORD_enum;
    KEYWORD_combinational;
    KEYWORD_sequential;
    KEYWORD_external;
    // KEYWORD_constant;
    // KEYWORD_wire;
    // KEYWORD_latch;
    // KEYWORD_flipflop;
    KEYWORD_using;
    KEYWORD_for;
    KEYWORD_if;
    KEYWORD_else;
    KEYWORD_in;
    KEYWORD_out;
    _END_KEYWORDS;

    ERROR;
    EOT;
}

Token :: struct {
    kind: Token_Kind;

    int_value: int;
    bit_width: int;

    string_value: string;

    using location: Source_Location;
}

Source_Location :: struct {
    line: int;
    start_char: int;
    end_char: int;
}

EOT : u8 : 0x4;

tokenize :: (source: string) -> [] Token {
    cursor: int;
    result: [..] Token;

    context.parser.source_code_lines = split(source, "\n");

    array_reserve(*result, source.count / 4);

    current :: () -> u8 #expand {
        if cursor >= source.count  return EOT;
        return source[cursor];
    }

    last_line_start: int = -1;
    start: int;
    line: int;

    Emit :: (kind: Token_Kind) -> *Token #expand {
        token := array_add(*result);
        token.kind = kind;

        token.line = line;
        token.start_char = start - last_line_start - 1;
        token.end_char = cursor - last_line_start;

        if token.kind == .ERROR {
            `return result;
        }

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

    while true {
        while current() == #char " " || current() == #char "\r" || current() == #char "\n" {
            if current() == #char "\n"  {
                last_line_start = cursor;
                line += 1;
            }
            cursor += 1;
        }

        start = cursor;
        if current() == {
          case #char ","; Emit(.COMMA);
          case #char "."; Emit(.DOT);
          case #char "+"; Emit(.OPERATOR_ADD);
          case #char ";"; Emit(.SEMICOLON);
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

          case #char "|";
            cursor += 1;
            if current() == #char "|"  Emit(.OPERATOR_LOGICAL_OR);
            else {
                cursor -= 1;
                Emit(.OPERATOR_BIT_OR);
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

          case #char ":";
            cursor += 1;
            if current() == #char ":"  Emit(.DOUBLE_COLON);
            else {
                cursor -= 1;
                Emit(.COLON);
            }

          case #char "-";
            cursor += 1;
            if current() == #char ">"  Emit(.ARROW);
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
            else {
                cursor -= 1;
                Emit(.OPERATOR_GREATER_THAN);
            }

          case #char "<";
            cursor += 1;
            if      current() == #char "="  Emit(.OPERATOR_LESS_OR_EQUAL);
            else if current() == #char "<"  Emit(.OPERATOR_SHIFT_LEFT);
            else {
                cursor -= 1;
                Emit(.OPERATOR_LESS_THAN);
            }

          case #char "/";
            cursor += 1;
            if current() == #char "/" {
                while current() != #char "\n" && current() != EOT cursor += 1;
            } else if current() == #char "*" {
                while true {
                    if current() == EOT Emit(.ERROR);
                    if current() == #char "/" && source[cursor-1] == #char "*" break;
                    if current() == #char "\n" line += 1;
                    cursor += 1;
                }
            } else {
                cursor -= 1;
                Emit(.OPERATOR_DIVIDE);
            }

          case 0; #through;
          case EOT;
            Emit(.EOT);
            return result;

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

                assert(success, tprint("%", value_str.count));

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
    }

    return result;
}

stringify_token :: (token: Token_Kind) -> string {
    if token == {
        case .COLON;                 return "Colon (:)";
        case .DOT;                   return "Dot (.)";
        case .OPERATOR_SUBTRACT;     return "Minus (-)";
        case .OPERATOR_ADD;          return "Plus (+)";
        case .OPERATOR_MULTIPLY;     return "Asterisk (*)";
        case .OPERATOR_DIVIDE;       return "Slash (/)";
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
        case .DOUBLE_COLON;          return "Double Colon (::)";
        case .OPERATOR_EQUALS;       return "Double Equals (==)";
        case .OPERATOR_LOGICAL_OR;   return "Logical Or (||)";
        case .ARROW;                 return "Arrow (->)";
        case .IDENTIFIER;            return "Identifier";
        case .INTEGER;               return "Integer";
        case .KEYWORD_chip;          return "Keyword 'chip'";
        case .KEYWORD_function;      return "Keyword 'function'";
        case .KEYWORD_struct;        return "Keyword 'struct'";
        case .KEYWORD_enum;          return "Keyword 'enum'";
        case .KEYWORD_combinational; return "Keyword 'combinational'";
        case .KEYWORD_sequential;    return "Keyword 'sequential'";
        case .KEYWORD_external;      return "Keyword 'external'";
        case .KEYWORD_using;         return "Keyword 'using'";
        case .KEYWORD_for;           return "Keyword 'for'";
        case .KEYWORD_if;            return "Keyword 'if'";
        case .KEYWORD_else;          return "Keyword 'else'";
        case .KEYWORD_in;            return "Keyword 'in'";
        case .KEYWORD_out;           return "Keyword 'out'";
        case .ERROR;                 return "(Unrecognised token)";
        case .EOT;                   return "End Of Text";

        case;
            assert(false, tprint("Tried to stringify token %\n", token));
            return "";
    }
}

lookup_keyword :: (ident: string) -> Token_Kind {
    ti := type_info(Token_Kind);

    for Token_Kind._BEGIN_KEYWORDS+1 .. Token_Kind._END_KEYWORDS-2 {
        name := ti.names[it];
        name.data += "KEYWORD_".count;
        name.count -= "KEYWORD_".count;

        if name == ident return cast(Token_Kind) it;
    }

    return .INVALID;
}
