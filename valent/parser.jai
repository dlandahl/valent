
#import "Basic";
#import "File";
#import "Compiler";
#import "String";

#run {
    set_build_options_dc(.{do_output = false});
    main();
}

main :: () {
    file := read_entire_file("simple.valent");
    tokens := tokenize(file);

    if tokens.count {
        if tokens[tokens.count-1].kind == .ERROR {
            print("Error! %\n", tokens[tokens.count-1]);
        }
    }

    line: int;
    lines := split(file, cast(u8) #char "\n");

    for tokens {
        if it.line > line {
            print("\n");
            line = it.line;
        }

        // token_text: string;
        // token_text.count = it.c1 - it.c0;
        // token_text.data = lines[it.line].data + it.c0;
        // print("%", token_text);

        if it.kind == .ERROR print("[31m");
        if it.kind == .STRING print("% ", it._string);
        else if it.kind == .IDENTIFIER print("% ", it._string);
        else if it.kind == .INTEGER print("% ", it._int);
        else print("% ", it.kind);
        if it.kind == .ERROR print("[0m");
    }

    ratio := cast(float) file.count / tokens.count;
    print("The ratio is %\n", ratio);

    context.parser = .{};
    context.parser.tokens = tokens;

    parse();
}


Ast_Node :: struct {
    Kind :: enum {
        NONE;
        DECLARATION;
        IDENTIFIER;
        BINOP;
        LITERAL;
        TYPE_DEFINITION;
        CHIP;
        SEQUENTIAL_CIRCUIT;
        ASSIGNMENT;
        IF;
    }

    kind: Kind;
}

Ast_Declaration :: struct {
    using #as node: Ast_Node;
    node.kind = .DECLARATION;

    name: string;
    type: *Ast_Node;
    value: *Ast_Node;
}

Ast_Identifier :: struct {
    using #as node: Ast_Node;
    node.kind = .IDENTIFIER;

    name: string;
    declaration: *Ast_Declaration;
}

Ast_Literal :: struct {
    type: *Datatype;

    union {
        int_value: int;
        string_value: string;
    };
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
    block: [] *Ast_Node;
}

Ast_Binop :: struct {
    using #as node: Ast_Node;
    node.kind = .BINOP;

    left: *Ast_Node;
    right: *Ast_Node;

    operation: enum {
        EQUALS;
        ADDITION;
        SUBTRACTION;
        ARRAY_INDEX;
    }
}

Ast_Unary_Op :: struct {
    using #as node: Ast_Node;
    node.kind = .BINOP;

    parameter: *Ast_Node;

    operation: enum {
        LOGIC_NOT;
        BIT_NOT;
    }
}

Ast_Chip :: struct {
    using #as node: Ast_Node;
    node.kind = .CHIP;

    constant_parameters: [] *Ast_Declaration;
    inputs: [] *Ast_Declaration;
    outputs: [] *Ast_Declaration;

    body: [] *Ast_Node;
}

Ast_Sequential_Circuit :: struct {
    using #as node: Ast_Node;
    node.kind = .SEQUENTIAL_CIRCUIT;

    clock: *Ast_Identifier;
    block: [] *Ast_Node;
}

Ast_Type_Definition :: struct {
    using #as node: Ast_Node;
    node.kind = .TYPE_DEFINITION;

    type: *Datatype;
}


Datatype :: struct {
    name: string;

    kind: Kind;
    primitive: Primitive;

    Kind :: enum {
        PRIMITIVE;
        STRUCT;
        ENUM;
        ARRAY;
    }

    Primitive :: enum {
        CONSTANT;
        WIRE;
        LATCH;
        FLIPFLOP;
        STRING;
        _COUNT;
    }

    fields: [] struct {
        name: string;
        type: *Datatype;
        value: float64;
    };

    array_type: *Datatype;
    element_count: int;
}


Parser :: struct {
    tokens: [] Token;
    token_index: int;
    top_level: [..] *Ast_Node;
}

#add_context parser: Parser;

parse :: () {
    while true {
        if allow(.EOT) {
            return;
        }

        s := parse_statement();
        array_add(*context.parser.top_level, s);
    }
}

parse_statement :: () -> *Ast_Node {

    if peek(.IDENTIFIER, distance = 1) {
        if peek(.COLON, .DOUBLE_COLON, distance = 2) {
            decl := parse_declaration();

            expect(.SEMICOLON);
            return decl;
        }

        if peek(.EQUALS, .SEQUENTIAL_ASSIGNMENT, distance = 2) {
            ident := expect(.IDENTIFIER);
            op := expect(.EQUALS, .SEQUENTIAL_ASSIGNMENT);

            ass := New(Ast_Assignment);
            ass.target = New(Ast_Identifier);
            ass.target.name = ident._string;
            ass.expr = parse_expression();
            ass.type = ifx op.kind == .EQUALS then .COMBINATIONAL else .SEQUENTIAL;

            expect(.SEMICOLON);
            return ass;
        }
    }

    if allow(.KEYWORD_if) {
        _if := New(Ast_If);
        _if.condition = parse_expression();

        expect(.OPEN_BRACE);

        block: [..] *Ast_Node;

        while true {
            if allow(.CLOSED_BRACE) break;

            statement := parse_statement();
            array_add(*block, statement);
        }

        _if.block = block;
        return _if;
    }

    if peek(.KEYWORD_sequential) {
        seq := parse_sequential_statement();
        return seq;
    }

    assert(false);
}

parse_declaration :: () -> *Ast_Declaration {
    decl := New(Ast_Declaration);

    ident := expect(.IDENTIFIER);
    decl.name = ident._string;

    if allow(.DOUBLE_COLON) {
        decl.value = parse_expression();
    } else if allow(.COLON) {
        decl.type = parse_expression();
    }

    return decl;
}

parse_expression :: () -> *Ast_Node {
    value := parse_comparison();

    while allow(.PLUS) {
        op := New(Ast_Binop);
        op.operation = .ADDITION;

        op.left = value;
        op.right = parse_comparison();

        value = op;
    }

    return value;
}

parse_comparison :: () -> *Ast_Node {
    value := parse_unary_prefix();

    while allow(.DOUBLE_EQUALS) {
        op := New(Ast_Binop);
        op.operation = .EQUALS;

        op.left = value;
        op.right = parse_unary_prefix();

        value = op;
    }

    return value;
}

parse_unary_prefix :: () -> *Ast_Node {
    if allow(.EXCLAMATION_MARK) {
        op := New(Ast_Unary_Op);
        op.parameter = parse_unary_prefix();
        op.operation = .LOGIC_NOT;

        return op;
    }

    return parse_array_index();
}

parse_array_index :: () -> *Ast_Node {
    value := parse_factor();

    while allow(.OPEN_BRACKET) {
        op := New(Ast_Binop);
        op.operation = .ARRAY_INDEX;
        op.left = value;
        op.right = parse_expression();

        expect(.CLOSED_BRACKET);

        value = op;
    }

    return value;
}

parse_factor :: () -> *Ast_Node {
    if allow(.IDENTIFIER) {
        ident := New(Ast_Identifier);
        ident.name = current()._string;

        return xx ident;
    }

    if allow(.INTEGER) {
        lit := New(Ast_Literal);
        // lit.type = *primitive_types[Datatype.Primitive.CONSTANT];
        lit.int_value = current()._int;

        return xx lit;
    }

    if allow(.STRING) {
        lit := New(Ast_Literal);
        // lit.type = *primitive_types[Datatype.Primitive.STRING];
        lit.string_value = current()._string;

        return xx lit;
    }

    if peek(.KEYWORD_chip) {
        return xx parse_chip();
    }

    return null;
}

parse_chip :: () -> *Ast_Chip {
    expect(.KEYWORD_chip);

    chip := New(Ast_Chip);
    constants, inputs, outputs := parse_parameter_list();

    chip.constant_parameters = constants;
    chip.inputs = inputs;
    chip.outputs = outputs;

    expect(.OPEN_BRACE);

    body: [..] *Ast_Node;

    while true {
        if allow(.CLOSED_BRACE) break;

        statement := parse_statement();
        array_add(*body, statement);
    }

    chip.body = body;
    return chip;
}

parse_sequential_statement :: () -> *Ast_Sequential_Circuit {
    expect(.KEYWORD_sequential);
    expect(.OPEN_PAREN);

    sensitivity := parse_expression();
    assert(sensitivity.kind == .IDENTIFIER);

    expect(.CLOSED_PAREN);
    expect(.OPEN_BRACE);

    seq := New(Ast_Sequential_Circuit);
    seq.clock = cast(*Ast_Identifier) sensitivity;

    block: [..] *Ast_Node;

    while true {
        if allow(.CLOSED_BRACE) break;

        statement := parse_statement();
        array_add(*block, statement);
    }

    seq.block = block;
    return seq;
}

parse_parameter_list :: () -> [] *Ast_Declaration, [] *Ast_Declaration, [] *Ast_Declaration {
    started_with_paren := allow(.OPEN_PAREN);

    constants: [..] *Ast_Declaration;
    inputs: [..] *Ast_Declaration;
    outputs: [..] *Ast_Declaration;

    while peek(.IDENTIFIER) {
        decl := parse_declaration();
        array_add(*inputs, decl);
    }

    if allow(.VERTICAL_BAR) {
        constants = inputs;

        inputs.data = null;
        inputs.allocated = 0;
        inputs.count = 0;

        while peek(.IDENTIFIER) {
            decl := parse_declaration();
            array_add(*inputs, decl);
        }
    }

    if started_with_paren {
        expect(.CLOSED_PAREN);
    }

    if allow(.ARROW) {
        started_with_paren := allow(.OPEN_PAREN);

        while peek(.IDENTIFIER) {
            decl := parse_declaration();
            array_add(*outputs, decl);
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

    assert(false);
    return new;
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

current :: () -> Token {
    using context.parser;
    return tokens[token_index - 1]; // The last token that was allowed or expected
}



Token_Kind :: enum {
    NONE;

    COLON;
    DOT;
    MINUS;
    PLUS;
    ASTERISK;
    SLASH;
    COMMA;
    VERTICAL_BAR;
    SEMICOLON;
    EQUALS;
    EXCLAMATION_MARK;
    LESS_THAN;
    GREATER_THAN;
    OPEN_PAREN;
    CLOSED_PAREN;
    OPEN_BRACKET;
    CLOSED_BRACKET;
    OPEN_BRACE;
    CLOSED_BRACE;

    DOUBLE_COLON;
    DOUBLE_EQUALS;
    LOGICAL_OR;
    ARROW;
    SEQUENTIAL_ASSIGNMENT;

    IDENTIFIER;
    STRING;
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
    KEYWORD_in;
    KEYWORD_out;
    _END_KEYWORDS;

    ERROR;
    EOT;
}

Token :: struct {
    kind: Token_Kind;

    _string: string;
    _int: int;

    line, c0, c1: int;
}

EOT : u8 : 0x4;

tokenize :: (source: string) -> [] Token {
    cursor: int;
    result: [..] Token;

    array_reserve(*result, source.count / 4);

    current :: () -> u8 #expand {
        if cursor >= source.count  return EOT;
        return source[cursor];
    }

    last_line_start: int;
    start: int;
    line: int;

    Emit :: (kind: Token_Kind, _string := "", _int := 0) -> *Token #expand {
        token := array_add(*result);
        token.kind = kind;

        if _int    != 0  token._int = _int;
        if _string != "" token._string = _string;

        token.line = line;
        token.c0 = start - last_line_start - 1;
        token.c1 = cursor - last_line_start;

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
            cursor += 1;
            if current() == #char "\n"  {
                last_line_start = cursor;
                line += 1;
            }
        }

        start = cursor;
        if current() == {
          case #char ","; Emit(.COMMA);
          case #char "."; Emit(.DOT);
          case #char "+"; Emit(.PLUS);
          case #char ";"; Emit(.SEMICOLON);
          case #char "*"; Emit(.ASTERISK);
          case #char "/"; Emit(.SLASH);
          case #char "("; Emit(.OPEN_PAREN);
          case #char ")"; Emit(.CLOSED_PAREN);
          case #char "["; Emit(.OPEN_BRACKET);
          case #char "]"; Emit(.CLOSED_BRACKET);
          case #char "{"; Emit(.OPEN_BRACE);
          case #char "}"; Emit(.CLOSED_BRACE);
          case #char ">"; Emit(.GREATER_THAN);
          case #char "!"; Emit(.EXCLAMATION_MARK);

          case #char "|";
            cursor += 1;
            if current() == #char "|"  Emit(.LOGICAL_OR);
            else {
                cursor -= 1;
                Emit(.VERTICAL_BAR);
            }

          case #char ":";
            cursor += 1;
            if      current() == #char ":"  Emit(.DOUBLE_COLON);
            else {
                cursor -= 1;
                Emit(.COLON);
            }

          case #char "-";
            cursor += 1;
            if      current() == #char ">"  Emit(.ARROW);
            else {
                cursor -= 1;
                Emit(.MINUS);
            }

          case #char "=";
            cursor += 1;
            if      current() == #char "="  Emit(.DOUBLE_EQUALS);
            else {
                cursor -= 1;
                Emit(.EQUALS);
            }

          case #char "<";
            cursor += 1;
            if      current() == #char "="  Emit(.SEQUENTIAL_ASSIGNMENT);
            else {
                cursor -= 1;
                Emit(.LESS_THAN);
            }

          case 0; #through;
          case EOT;
            Emit(.EOT);
            return result;

          case #char "\"";
            cursor += 1;
            text: string;
            text.data = source.data + cursor;

            while current() != #char "\"" && current() != EOT && current() != #char "\n" {
                text.count += 1;
                cursor += 1;
            }

            if current() == #char "\""
                then Emit(.STRING, _string = text);
                else Emit(.ERROR);

          case;
            if is_num(current()) {
                base: int = 10;

                if current() == #char "0" {
                    cursor += 1;
                    if current() == {
                      case #char "x";
                        base = 16;
                        cursor += 1;
                      case #char "b";
                        base = 2;
                        cursor += 1;
                      case;
                        cursor -= 1;
                    }
                }

                len: int;
                while is_num(current()) || is_char(current()) {
                    cursor += 1;
                    len += 1;
                }
                cursor -= 1;

                num_str: string;
                num_str.data = source.data + cursor - len + 1;
                num_str.count = len;
                num := string_to_int(num_str, base = base);

                Emit(.INTEGER, _int = num);
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

                if keyword != .NONE Emit(keyword);
                else Emit(.IDENTIFIER, _string = ident);
            }

            else {
                Emit(.ERROR);
            }
        }

        cursor += 1;
    }

    return result;
}

lookup_keyword :: (ident: string) -> Token_Kind {
    ti := type_info(Token_Kind);

    for Token_Kind._BEGIN_KEYWORDS+1 .. Token_Kind._END_KEYWORDS-2 {
        name := ti.names[it];
        name.data += "KEYWORD_".count;
        name.count -= "KEYWORD_".count;

        if name == ident return cast(Token_Kind) it;
    }

    return .NONE;
}
