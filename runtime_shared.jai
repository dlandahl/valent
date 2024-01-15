
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
        JAI_CODE;
        STOP_MARKER;
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

Ast_Jai_Code :: struct {
    using #as node: Ast_Node;
    node.kind = .JAI_CODE;

    block_type: enum {
        GENERATE;
        TESTBENCH;
    }

    code: string;
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

    target: *Ast_Node; // Concat or ident
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

Datatype :: struct {

    // Kind :: enum {
    //     INVALID;
    //     PRIMITIVE;
    //     STRUCT;
    //     ENUM;
    //     ARRAY;
    // }

    Primitive :: enum {
        INVALID;
        CONSTANT;
        WIRE;
        LATCH;
        FLIPFLOP;
        CHIP;
        CHIP_INSTANTIATION;
        _COUNT;
    }

    primitive: Primitive;
    bit_width: int; // -1 means constant with no specific width
}

Block_Type :: enum {
    NONE;
    TOP_LEVEL;
    CHIP;
    SEQUENTIAL;
    COMBINATIONAL;
    _COUNT;
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
    KEYWORD_generate;
    _END_KEYWORDS;

    JAI_CODE;

    ERROR;
    EOT;
}

Source_Location :: struct {
    line: int;
    start_char: int;
    end_char: int;
}

Generate_Block_User_Data :: struct {
    parent_block: *Ast_Block;
    num_emitted: int;
    syntax_trees: [1000] *Ast_Node;
}
