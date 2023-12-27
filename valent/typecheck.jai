
#import "Hash_Table";

compile :: (top_level: *Ast_Block, top: string) -> *Ast_Declaration {

    for top_level.statements {
        // Todo: check for duplicate names at top level
        assert(it.kind == .DECLARATION);

        decl := cast(*Ast_Declaration) it;
        if decl.name == top {
            assert(decl.initialisation_value.kind == .CHIP);

            compile_top(cast(*Ast_Chip) decl.initialisation_value);
            return decl;
        }
    }

    return null;
}

compile_top :: (chip: *Ast_Chip) {
    assert(chip.constant_parameters.count == 0, "To do");

    for chip.inputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.datatype;
        if !is_primitive_or_array_of_primitive(t, .WIRE) {
            semantic_error(it, "each input port of a chip must a be wire or a bus of wires. (Got type %)", t);
        }
    }

    for chip.outputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.datatype;
        if !is_primitive_or_array_of_primitive(t, .WIRE) && !is_primitive_or_array_of_primitive(t, .FLIPFLOP) {
            semantic_error(it, "each output port of a chip must a be wire, a flipflop, or a bus of wires or flipflops. (Got type %)", t);
        }
    }

    typecheck(cast(*Ast_Block) chip);
}

Typechecker :: struct {
    current_block: *Ast_Block;
}

is_primitive_or_array_of_primitive :: (t: Datatype, p: Datatype.Primitive) -> bool {
    return t.primitive == p || (t.array_type && t.array_type.primitive == p);
}

#add_context typechecker: Typechecker;

typecheck :: (block: *Ast_Block) {
    names: Table(string, *Ast_Declaration);

    Duplication_Check :: (decl: *Ast_Declaration) #expand {
        existing := table_find_pointer(*names, decl.name);

        if existing != null {
            l1 := node_location_string(<< existing);
            l2 := node_location_string(decl);
            semantic_error(decl, "name '%' has multiple declarations in the same block.\n\n%\n\n%", decl.name, l1, l2);
        }

        table_add(*names, decl.name, decl);
    }

    if block.block_type == .CHIP {
        chip := cast(*Ast_Chip) block;

        for chip.constant_parameters Duplication_Check(it);
        for chip.inputs              Duplication_Check(it);
        for chip.outputs             Duplication_Check(it);
    }

    context.typechecker.current_block = block;
    defer context.typechecker.current_block = block.parent;

    for block.statements {
        if it.kind == {

          case .DECLARATION;
            decl := cast(*Ast_Declaration) it;

            Duplication_Check(decl);

            if !decl.typechecked {
                typecheck_declaration(decl);
            }

          case .ASSIGNMENT;
            ass := cast(*Ast_Assignment) it;

            if block.block_type == {
                case .SEQUENTIAL;    assert(ass.type == .SEQUENTIAL);
                case .COMBINATIONAL; assert(ass.type == .COMBINATIONAL);
                case; assert(false);
            }

            resolve_identifier(ass.target);
            typecheck_declaration(ass.target.resolved_declaration);
            typecheck_expression(ass.expr);

            if block.block_type == .SEQUENTIAL && !is_primitive_or_array_of_primitive(ass.target.datatype, .FLIPFLOP) {
                semantic_error(ass, "sequential blocks may only contain assignments to clocked elements (flipflops)\n\n%", node_location_string(ass));
            }

            if block.block_type == .COMBINATIONAL && !is_primitive_or_array_of_primitive(ass.target.datatype, .WIRE) {
                semantic_error(ass, "combinational blocks may only contain assignments to unclocked elements (wires)\n\n%", node_location_string(ass));
            }

          case .IF;
            _if := cast(*Ast_If) it;
            typecheck_expression(_if.condition);
            typecheck(_if.block);

            if _if.else_block {
                typecheck(_if.else_block);
            }

          case .SEQUENTIAL_CIRCUIT;
            seq := cast(*Ast_Sequential_Circuit) it;
            resolve_identifier(seq.clock);
            typecheck(seq.block);

          case .COMBINATIONAL_CIRCUIT;
            comb := cast(*Ast_Combinational_Circuit) it;
            typecheck(comb.block);

          case;
            assert(false);
        }
    }

    block.typechecked = true;
}

typecheck_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    defer expr.typechecked = true;

    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        lit.datatype = .{ kind = .PRIMITIVE, primitive = .CONSTANT };

      case .IDENTIFIER;
        id := cast(*Ast_Identifier) expr;

        if !id.resolved_declaration {
            resolve_identifier(id);
        }

        if !id.resolved_declaration.typechecked {
            typecheck_declaration(id.resolved_declaration);
        }

        id.datatype = id.resolved_declaration.datatype;

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        typecheck_expression(op.argument);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        typecheck_expression(op.left);
        typecheck_expression(op.right);

        if op.operation == {
          case;
            assert(types_match(op.left.datatype, op.right.datatype));
        }

      case;
        assert(false);
    }
}

typecheck_declaration :: (decl: *Ast_Declaration) {
    assert(decl.initialisation_value || decl.type_expression);

    if decl.initialisation_value {
        typecheck_expression(decl.initialisation_value);
    }

    if decl.type_expression {
        evaluate_type_expression(decl.type_expression);
    }

    if decl.type_expression && decl.initialisation_value {
        assert(types_match(decl.type_expression.datatype, decl.initialisation_value.datatype));
    }

    if decl.type_expression {
        decl.datatype = decl.type_expression.datatype;
    } else {
        decl.datatype = decl.initialisation_value.datatype;
    }

    decl.typechecked = true;
}

// Should move this to parsing
evaluate_type_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    defer expr.typechecked = true;

    if expr.kind == .IDENTIFIER {
        expr.datatype.kind = .PRIMITIVE;

        ident := cast(*Ast_Identifier) expr;

        if ident.name == {
          case "flipflop";
            expr.datatype.primitive = .FLIPFLOP;

          case "wire";
            expr.datatype.primitive = .WIRE;

          case;
            semantic_error(expr, "name is not a type.\n\n%", node_location_string(ident));
        }

        return;
    }

    if expr.kind == .BINARY_OP {
        op := cast(*Ast_Binary_Op) expr;
        assert(op.operation == .OPEN_BRACKET);

        expr.datatype.kind = .ARRAY;

        expr.datatype.array_type = New(Datatype);
        evaluate_type_expression(op.left);
        expr.datatype.array_type.* = op.left.datatype;
        expr.datatype.element_count = 0; // evaluate_constant_expression(op.right);

        // typecheck_expression(op.right);

        return;
    }

    semantic_error(expr, "expression is not type-valued (Ast kind %)", expr.kind);
}

types_match :: (left: Datatype, right: Datatype) -> bool {
    return true;
}

resolve_identifier :: (id: *Ast_Identifier) {

    search_in_block :: (block: *Ast_Block, name: string) -> *Ast_Declaration {
        if block.block_type == .CHIP {
            chip := cast(*Ast_Chip) block;
            for chip.constant_parameters if it.name == name return it;
            for chip.inputs if it.name == name return it;
            for chip.outputs if it.name == name return it;
        }

        for block.statements {
            if it.kind == .DECLARATION {
                decl := cast(*Ast_Declaration) it;
                if decl.name == name return decl;
            }
        }

        if block.parent {
            return search_in_block(block.parent, name);
        }

        return null;
    }

    decl := search_in_block(context.typechecker.current_block, id.name);
    if !decl {
        semantic_error(id, "Could not find declaration when trying to resolve identifier '%', referenced here:\n\n%", id.name, node_location_string(id));
    }

    typecheck_declaration(decl);
    id.datatype = decl.datatype;

    id.resolved_declaration = decl;
}

semantic_error :: (ast: *Ast_Node, report: string, format: .. Any) {
    print("\nSemantic error: %\n", tprint(report, .. format));

    exit(1);
}

node_location_string :: (node: *Ast_Node) -> string {
    loc := node.location;
    line := context.parser.source_code_lines[loc.line];

    first := line;
    first.count = loc.start_char;

    second := line;
    second.data += loc.start_char;
    second.count = loc.end_char - loc.start_char;

    third := line;
    third.data += loc.end_char;
    third.count -= loc.end_char;

    return tprint("line %:%[31m%[0m%", loc.line, first, second, third);
}
