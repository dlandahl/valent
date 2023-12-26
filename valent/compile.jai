
#import "Hash_Table";

compile :: (top_level: *Ast_Block, top: string) {

    for top_level.statements {
        // Todo: check for duplicate names at top level
        assert(it.kind == .DECLARATION);

        decl := cast(*Ast_Declaration) it;
        if decl.name == top {
            assert(decl.initialisation_value.kind == .CHIP);

            compile_top(cast(*Ast_Chip) decl.initialisation_value);
        }
    }
}

compile_top :: (chip: *Ast_Chip) {
    assert(chip.constant_parameters.count == 0, "To do");

    for chip.inputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.datatype;
        if !(t.primitive == .WIRE || (t.array_type && t.array_type.primitive == .WIRE)) {
            semantic_error(it, "each input port of a chip must a be wire or a bus of wires. (Got type %)", t);
        }
    }

    for chip.outputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.datatype;
        if !(t.primitive == .WIRE || (t.array_type && t.array_type.primitive == .WIRE)) && !(t.primitive == .FLIPFLOP || (t.array_type && t.array_type.primitive == .FLIPFLOP)) {
            semantic_error(it, "each output port of a chip must a be wire, a flipflop, or a bus of wires or flipflops. (Got type %)", t);
        }
    }

    typecheck(cast(*Ast_Block) chip);
}

Typechecker :: struct {
    current_block: *Ast_Block;
}

#add_context typechecker: Typechecker;

typecheck :: (block: *Ast_Block) {
    names: Table(string, *Ast_Declaration);

    if block.block_type == .CHIP {

        Duplication_Check :: (decl: *Ast_Declaration) #expand {
            if table_contains(*names, decl.name) {
                assert(false);
            }

            table_add(*names, decl.name, decl);
        }

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

            if table_contains(*names, decl.name) {
                assert(false);
            }

            table_add(*names, decl.name, decl);

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
            typecheck_expression(ass.expr);

            if !types_match(ass.target.datatype, ass.expr.datatype) {
                assert(false);
            }

          case .IF;
            _if := cast(*Ast_If) it;
            typecheck_expression(_if.condition);
            typecheck(_if.block);

          case .SEQUENTIAL_CIRCUIT;
            seq := cast(*Ast_Sequential_Circuit) it;
            resolve_identifier(seq.clock);
            typecheck(seq.block);

          case;
            assert(false);
        }
    }
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
            assert(false);
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

        return;
    }

    semantic_error(expr, "Expression is not type-valued (Ast kind %)", expr.kind);
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
    assert(decl != null);

    id.resolved_declaration = decl;
}

semantic_error :: (ast: *Ast_Node, report: string, format: .. Any) {
    print("Semantic error: %\n", tprint(report, format));

    assert(false);
}
