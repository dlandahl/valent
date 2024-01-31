
#scope_module

#import "Hash_Table";

// typecheck :: (top_level: *Ast_Block, top: string) -> *Ast_Declaration {
// 
//     for top_level.statements {
//         // Todo: check for duplicate names at top level
//         assert(it.kind == .DECLARATION);
// 
//         decl := cast(*Ast_Declaration) it;
//         if decl.name == top {
//             assert(decl.initialisation_value.kind == .MODULE);
// 
//             decl.datatype.primitive = .MODULE;
//             decl.typechecked = true;
// 
//             typecheck_module(cast(*Ast_Module) decl.initialisation_value);
//             return decl;
//         }
//     }
// 
//     semantic_error(top_level, "top module '%' was not found in the provided program", top);
// 
//     return null;
// }

typecheck_module :: (module: *Ast_Module) {
    assert(module.constant_parameters.count == 0, "To do");
    context.typechecker.current_block = module;

    for module.inputs {
        evaluate_type_expression(it.type_expression);
        it.datatype = it.type_expression.datatype;

        if it.type_expression.datatype.primitive != .WIRE {
            semantic_error(it, "Each input port of a module must a be wire or a bus of wires\n\n%", node_location_string(it));
        }
    }

    for module.outputs {
        evaluate_type_expression(it.type_expression);
        it.datatype = it.type_expression.datatype;

        // Todo: say what the type was
        if it.type_expression.datatype.primitive != .WIRE && it.type_expression.datatype.primitive != .FLIPFLOP {
            semantic_error(it, "Each output port of a module must a be wire, a flipflop, or a bus of wires or flipflops\n\n%", node_location_string(it));
        }
    }

    typecheck_block(cast(*Ast_Block) module);
}

Typechecker :: struct {
    current_block: *Ast_Block;
    in_progress: [..] *Ast_Node;
}

#add_context typechecker: Typechecker;

typecheck_block :: (block: *Ast_Block) {
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

    if block.block_type == .MODULE {
        module := cast(*Ast_Module) block;

        for module.constant_parameters Duplication_Check(it);
        for module.inputs              Duplication_Check(it);
        for module.outputs             Duplication_Check(it);
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
                case .SEQUENTIAL; if ass.type == .COMBINATIONAL
                    semantic_error(ass, "Assignments in sequential blocks must be sequential assignments (<=)\n\n%", node_location_string(ass));
                case .COMBINATIONAL; if ass.type == .SEQUENTIAL
                    semantic_error(ass, "Assignments in combinational blocks must be combinational assignments (=)\n\n%", node_location_string(ass));
                case; assert(false);
            }

            /*
            lhs_type: Datatype;
            if ass.target.kind == .IDENTIFIER {
                ident := cast(*Ast_Identifier) ass.target;

                resolve_identifier(ident);

                lhs_type = ident.resolved_declaration.datatype;
            } else if ass.target.kind == .CONCAT {
                typecheck_expression(ass.target);
                // Todo: check this is only 0/Z literals and wire or flipflop idents depending on block type
                lhs_type = ass.target.datatype;
            }
            */

            typecheck_expression(ass.target);

            Walk_Expression(ass.target, #code {
                if expr.kind == .LITERAL {
                    lit := cast(*Ast_Literal) expr;
                    if lit.int_value != 0 semantic_error(lit, "Literals in lvalue concatenations must be zero - they only align the writable elements.\n\n%", node_location_string(lit));
                }
            });

            typecheck_expression(ass.expr);

            if block.block_type == .SEQUENTIAL && ass.target.datatype.primitive != .FLIPFLOP {
                semantic_error(ass, "Sequential blocks may only contain assignments to clocked elements (flipflops)\n\n%", node_location_string(ass));
            }

            if block.block_type == .COMBINATIONAL && ass.target.datatype.primitive != .WIRE {
                semantic_error(ass, "Combinational blocks may only contain assignments to unclocked elements (wires)\n\n%", node_location_string(ass));
            }

            if ass.target.datatype.module_input {
                semantic_error(ass, "A module input parameter must not be the target of an assignment\n\n%", node_location_string(ass.target));
            }

            if ass.target.datatype.enum_def {
                if ass.expr.datatype.enum_def != ass.target.datatype.enum_def {
                    semantic_error(ass, "In this assignment, the left side has an enum tag, but the right side is not a member of that enum\n\n%", node_location_string(ass));
                }
            }

            if ass.trunc && ass.target.datatype.bit_width < ass.expr.datatype.bit_width {
            } else {
                check_bit_width(ass, ass.target.datatype, ass.expr.datatype);
            }

          case .IF;
            _if := cast(*Ast_If) it;
            typecheck_expression(_if.condition);
            typecheck_block(_if.block);

            if _if.else_block {
                typecheck_block(_if.else_block);
            }

          case .SWITCH;
            switch := cast(*Ast_Switch) it;
            typecheck_expression(switch.condition);

            for switch.cases {
                typecheck_expression(it.compare);

                if switch.condition.datatype.enum_def {
                    if switch.condition.datatype.enum_def != it.compare.datatype.enum_def {
                        semantic_error(it.compare, "This switch statement is over an enum value, so all cases should be values of that enum\n\n%", node_location_string(it.compare));
                    }
                }

                typecheck_block(it.block);
            }

          case .SEQUENTIAL_CIRCUIT;
            seq := cast(*Ast_Sequential_Circuit) it;
            resolve_identifier(seq.clock);
            typecheck_block(seq.block);

          case .COMBINATIONAL_CIRCUIT;
            comb := cast(*Ast_Combinational_Circuit) it;
            typecheck_block(comb.block);

          case .JAI_CODE;
            jai := cast(*Ast_Jai_Code) it;
            print("Found Jai code %\n", jai.code);
          case;
            assert(false);
        }
    }

    block.typechecked = true;
}

typecheck_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    if expr.kind == .IDENTIFIER {
        if array_find(context.typechecker.in_progress, expr) {
            builder: String_Builder;
            defer free_buffers(*builder);

            print_to_builder(*builder, "This expression is involved in a circular dependency:\n\n%\n\n", node_location_string(context.typechecker.in_progress[0]));

            for context.typechecker.in_progress {
                if it_index == 0 continue;
                print_to_builder(*builder, "... % depends on\n%\n\n", ifx it_index == 1 then "it" else "which", node_location_string(it));
            }

            print_to_builder(*builder, "which we've seen before.");

            semantic_error(expr, builder_to_string(*builder));
        }

        array_add(*context.typechecker.in_progress, expr);
    }

    defer if expr.kind == .IDENTIFIER {
        expr.typechecked = true;
        pop(*context.typechecker.in_progress);
    }

    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        lit.datatype = .{ primitive = .CONSTANT };
        lit.datatype.bit_width = lit.bit_width;

      case .IDENTIFIER;
        id := cast(*Ast_Identifier) expr;

        if !id.resolved_declaration {
            resolve_identifier(id);
        }

        id.datatype = id.resolved_declaration.datatype;

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        typecheck_expression(op.argument);

        op.datatype = op.argument.datatype;

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        typecheck_expression(op.left);

        if op.operation == .OPERATOR_DOT {
            if op.left.datatype.primitive != .ENUM && !op.left.datatype.register_def {
                semantic_error(op, "Dot dereference (.) used on type '%', but only works on enums or registers.\n\n%", op.left.datatype.primitive, node_location_string(op));
            }

            if op.right.kind != .IDENTIFIER {
                semantic_error(op, "Expected an identifier to the right of dot dereference (.).\n\n%", node_location_string(op));
            }

            ident := cast(*Ast_Identifier) op.right;

            if op.left.datatype.primitive == .ENUM {
                enum_def := op.left.datatype.enum_def;
                op.datatype.primitive = .CONSTANT;
                op.datatype.bit_width = op.left.datatype.bit_width;
                op.datatype.enum_def = enum_def;

                found: bool;
                for enum_def.fields if it.name == ident.name {
                    found = true;
                    break;
                }

                if !found {
                    semantic_error(op, "Name '%' was not found in the enum\n\n%", ident.name, node_location_string(op.right)); // Todo show the declaration
                }

            } else if op.left.datatype.register_def != null {
                reg := op.left.datatype.register_def;

                field: *Register_Def.Field;
                for *reg.fields if it.name == ident.name {
                    field = it;
                    break;
                }

                if field == null {
                    semantic_error(op.left, "The name '%' was not found in the register\n\n%", ident.name, node_location_string(op.right)); // Todo show the declaration
                }

                op.datatype.primitive = op.left.datatype.primitive;
                op.datatype.bit_width = field.width;
                op.datatype.enum_def = field.enum_def;
                op.datatype.register_def = field.register_def;

            } else {
                assert(false);
            }
        } else {
            typecheck_expression(op.right);
            op.datatype = op.left.datatype;

            if op.operation == .OPERATOR_REPEAT {
                op.datatype = op.right.datatype;
                count := evaluate_constant_expression(op.left);
                op.datatype.bit_width *= count;
            } else if op.operation != .OPEN_BRACKET {
                op.datatype.bit_width = max(op.left.datatype.bit_width, op.right.datatype.bit_width);

                if op.operation == .OPERATOR_ADD              op.datatype.bit_width += 1;
                if op.operation == .OPERATOR_MULTIPLY         op.datatype.bit_width *= 2;
                if op.operation == .OPERATOR_EQUALS           op.datatype.bit_width = 1;
                if op.operation == .OPERATOR_LESS_THAN        op.datatype.bit_width = 1;
                if op.operation == .OPERATOR_GREATER_OR_EQUAL op.datatype.bit_width = 1;
                if op.operation == .OPERATOR_LESS_OR_EQUAL    op.datatype.bit_width = 1;
                if op.operation == .OPERATOR_GREATER_THAN     op.datatype.bit_width = 1;

            } else {
                if op.right.kind == .BIT_SELECT {
                    sel := cast(*Ast_Bit_Select) op.right;

                    left  := evaluate_constant_expression(sel.left);
                    right := evaluate_constant_expression(sel.right);

                    op.datatype.bit_width = left - right + 1;
                } else {
                    op.datatype.bit_width = 1;
                }
            }
        }

      case .BIT_SELECT;

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;
        bit_width: int;

        any_flipflops: bool;
        any_wires: bool;

        for cat.fields {
            typecheck_expression(it);

            if it.datatype.bit_width == -1 {
                semantic_error(cat, "All entries of a concatenation must have an explicit width, but this one doesn't\n\n%", node_location_string(it));
            }
            bit_width += it.datatype.bit_width;

            any_flipflops ||= it.datatype.primitive == .FLIPFLOP;
            any_wires     ||= it.datatype.primitive == .WIRE;

            cat.datatype.module_input ||= it.datatype.module_input;
        }

        cat.datatype.bit_width = bit_width;
        if any_flipflops && !any_wires cat.datatype.primitive = .FLIPFLOP;
        if !any_flipflops && any_wires cat.datatype.primitive = .WIRE;

      case .MODULE;
        mod := cast(*Ast_Module) expr;
        typecheck_module(mod);
    }
}

check_bit_width :: (ast: *Ast_Node, left: Datatype, right: Datatype) -> int {
    assert(left.bit_width != 0);
    assert(right.bit_width != 0);

    if left.bit_width == -1 && right.bit_width != -1 return right.bit_width;
    if left.bit_width != -1 && right.bit_width == -1 return left.bit_width;
    if left.bit_width == -1 && right.bit_width == -1 return -1;

    if left.bit_width != right.bit_width {
        loc := node_location_string(ast);
        semantic_error(ast, "bit widths do not match in this operation\n\n%\n\nLeft width is %, right is %", loc, left.bit_width, right.bit_width);
    }

    return left.bit_width;
}

typecheck_declaration :: (decl: *Ast_Declaration) {
    assert(decl.initialisation_value || decl.type_expression);

    if decl.typechecked return;

    array_add(*context.typechecker.in_progress, decl);
    defer pop(*context.typechecker.in_progress);

    if decl.initialisation_value && decl.datatype.is_type {
        evaluate_type_expression(decl.initialisation_value);
        decl.datatype = decl.initialisation_value.datatype;
    } else if decl.type_expression {
        evaluate_type_expression(decl.type_expression);
        decl.datatype = decl.type_expression.datatype;
    } else {
        // Infer the type from the value
        typecheck_expression(decl.initialisation_value);
        decl.datatype = decl.initialisation_value.datatype;
    }
    decl.datatype.module_input = decl.module_input;

    prim := decl.datatype.primitive;
    if prim == .CONSTANT || prim == .MODULE || prim == .ENUM {
        if !decl.constant {
            semantic_error(decl, "declarations of type % must be constant. Use `name :: value` here instead of `name: type`\n\n%", prim, node_location_string(decl)); // Todo: stringify type name
        }
    }

    decl.typechecked = true;
}

evaluate_type_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    defer expr.typechecked = true;
    root := expr;

    if expr.kind == .ENUM {
        root.datatype.primitive = .ENUM;
        root.datatype.enum_def = New(Enum_Def);

        _enum := cast(*Ast_Enum) expr;

        last_value := -1;
        largest: int;

        for _enum.fields {
            new := array_add(*_enum.datatype.enum_def.fields);
            new.name = it.name;

            if it.value_expr != null {
                new.value = evaluate_constant_expression(it.value_expr);
            } else {
                new.value = last_value + 1;
            }

            if new.value > largest largest = new.value;
            last_value = new.value;
        }

        bits_needed := bit_scan_reverse(largest);

        if _enum.width {
            root.datatype.bit_width = evaluate_constant_expression(_enum.width);
            if root.datatype.bit_width < bits_needed {
                semantic_error(root, "This enum requires % bits to represent its values, but has specifically been given a width of only %\n\n%\n", bits_needed, root.datatype.bit_width, node_location_string(_enum));
            }
        } else {
            root.datatype.bit_width = -1;
        }

        return;

    } else if expr.kind == .REGISTER {

        root.datatype.primitive = .REGISTER;
        root.datatype.register_def = New(Register_Def);

        reg := cast(*Ast_Register) expr;

        total_width: int;

        for reg.fields {
            new := array_add(*reg.datatype.register_def.fields);
            new.name = it.name;

            if it.width_expr {
                typecheck_expression(it.width_expr);

                if it.width_expr.datatype.primitive == {
                  case .ENUM;
                    new.enum_def = it.width_expr.datatype.enum_def;
                    if it.width_expr.datatype.bit_width == -1 {
                        ident := cast(*Ast_Identifier) it.width_expr;
                        semantic_error(root, "This register contains an enum without a specific width:\n\n%\n\nThis is the enum (use `enum[N]` here):\n\n%", node_location_string(root), node_location_string(ident.resolved_declaration));
                    }
                    new.width += it.width_expr.datatype.bit_width;

                  case .REGISTER;
                    new.register_def = it.width_expr.datatype.register_def;
                    new.width = it.width_expr.datatype.bit_width;
                    

                  case;
                    new.width = evaluate_constant_expression(it.width_expr);
                }
            } else {
                new.width = 1;
            }

            total_width += new.width;
        }

        root.datatype.bit_width = total_width;

        if reg.width_expr {
            provided_width := evaluate_constant_expression(reg.width_expr);
            if total_width != provided_width {
                semantic_error(reg, "This register has been given an explicit width of % bits, but is actually % bits wide:\n\n%", provided_width, total_width, node_location_string(reg.width_expr));
            }
        }

        return;
    } else if expr.kind == .BINARY_OP { // Bus
        op := cast(*Ast_Binary_Op) expr;

        if op.operation != .OPEN_BRACKET {
            l := node_location_string(expr);
            semantic_error(expr, "Expected a type here.\n\n%", l);
        }

        typecheck_expression(op.right);

        if op.right.datatype.primitive == .ENUM {
            root.datatype.bit_width = op.right.datatype.bit_width;
            assert(op.right.kind == .IDENTIFIER); // Todo error

            ident := cast(*Ast_Identifier) op.right;
            root.datatype.enum_def = ident.datatype.enum_def;

            if root.datatype.bit_width == -1 {
                semantic_error(ident, "Cannot create a circuit element based on an enum without a specific width:\n\n%\n\nUse `enum[N]` here:\n\n%", node_location_string(ident), node_location_string(ident.resolved_declaration.initialisation_value));
            }

            assert(expr.datatype.enum_def != null);
        } else if op.right.datatype.primitive == .REGISTER {
            root.datatype.bit_width = op.right.datatype.bit_width;
            assert(op.right.kind == .IDENTIFIER); // Todo error

            ident := cast(*Ast_Identifier) op.right;
            assert(ident.datatype.register_def != null);
            root.datatype.register_def = ident.datatype.register_def;
        } else {
            root.datatype.bit_width = evaluate_constant_expression(op.right);
        }

        expr = op.left;
    } else if expr.kind == .MODULE {
        typecheck_module(cast(*Ast_Module) expr);
        return;
    } else {
        expr.datatype.bit_width = 1;
    }

    if expr.kind != .IDENTIFIER {
        l := node_location_string(expr);
        semantic_error(expr, "Expected a type here.\n\n%", l);
    }

    ident := cast(*Ast_Identifier) expr;

    if ident.name == {
      case "flipflop";
        root.datatype.primitive = .FLIPFLOP;

      case "wire";
        root.datatype.primitive = .WIRE;

      case;
        semantic_error(expr, "name is not a type.\n\n%", node_location_string(ident));
    }
}

evaluate_constant_expression :: (expr: *Ast_Node) -> int {

    internal_evaluate :: (expr: *Ast_Node) -> int {
        if expr.kind == {
          case .LITERAL;
            lit := cast(*Ast_Literal) expr;
            return lit.int_value;

          case .UNARY_OP;
            op := cast(*Ast_Unary_Op) expr;
            arg := internal_evaluate(op.argument);

            if op.operation == .LOGIC_NOT return cast(int) !arg;
            if op.operation == .BIT_NOT return ~arg;

          case .BINARY_OP;
            op := cast(*Ast_Binary_Op) expr;

            if op.operation == .OPERATOR_DOT {
                assert(op.left.datatype.enum_def != null);
                assert(op.right.kind == .IDENTIFIER);

                ident := cast(*Ast_Identifier) op.right;
                
                for op.left.datatype.enum_def.fields {
                    if it.name == ident.name return it.value;
                }

                semantic_error(op, "Name '%' was not found in the enum\n\n%", ident.name, node_location_string(op.right));
            }

            left := internal_evaluate(op.left);
            right := internal_evaluate(op.right);

            if op.operation == {
                case .OPERATOR_ADD;          return left + right;
                case .OPERATOR_SUBTRACT;     return left - right;
                case .OPERATOR_MULTIPLY;     return left * right;
                case .OPERATOR_DIVIDE;       return left / right;
                case .OPERATOR_BIT_OR;       return left | right;
                case .OPERATOR_LESS_THAN;    return cast(int) (left < right);
                case .OPERATOR_GREATER_THAN; return cast(int) (left > right);
                case .OPERATOR_EQUALS;       return cast(int) (left == right);
                case .OPERATOR_LOGICAL_OR;   return cast(int) (left || right);
                case; assert(false);
            }

          case .IDENTIFIER;
            id := cast(*Ast_Identifier) expr;

            prim := id.resolved_declaration.datatype.primitive;
            if prim == .MODULE || prim == .LATCH || prim == .WIRE || prim == .FLIPFLOP {
                l1 := node_location_string(id);
                l2 := node_location_string(id.resolved_declaration);
                semantic_error(id, "This identifier was used in a constant expression, but refers to a circuit element.\n\n%\n\nDeclared here\n\n%", l1, l2);
            }

            if id.resolved_declaration.datatype.is_type {
                semantic_error(id, "Expected a constant expression, but got a type name:\n\n%\n\nDeclared here:\n\n%", node_location_string(id), node_location_string(id.resolved_declaration));
            }

            return internal_evaluate(id.resolved_declaration.initialisation_value); // Todo cache
        }

        assert(false);
        semantic_error(expr, "Tried to constant-evaluate an expression \n\n%\n", node_location_string(expr));
        return 0;
    }

    typecheck_expression(expr);
    return internal_evaluate(expr);
}

resolve_identifier :: (id: *Ast_Identifier) {

    search_in_block :: (block: *Ast_Block, name: string) -> *Ast_Declaration {
        if block.block_type == .MODULE {
            module := cast(*Ast_Module) block;

            for module.constant_parameters if it.name == name return it;
            for module.inputs if it.name == name return it;
            for module.outputs if it.name == name return it;
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
        semantic_error(id, "Undeclared identifier '%', referenced here:\n\n%", id.name, node_location_string(id));
    }

    typecheck_declaration(decl);
    id.datatype = decl.datatype;

    id.resolved_declaration = decl;
}

Walk_Expression :: (expr: *Ast_Node, $code: Code, $deferred: Code = #code {}, user_data: *$T = null) {

    #insert,scope() code;

    if expr.kind == {
      case .MODULE;
      case .BIT_SELECT;
        sel := cast(*Ast_Bit_Select) expr;
        Walk_Expression(sel.left, code, deferred, user_data);
        Walk_Expression(sel.right, code, deferred, user_data);

      case .LITERAL;
      case .IDENTIFIER;
      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        Walk_Expression(op.argument, code, deferred, user_data);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        Walk_Expression(op.left, code, deferred, user_data);
        Walk_Expression(op.right, code, deferred, user_data);

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;
        for cat.fields {
            Walk_Expression(it, code, deferred, user_data);
        }

      case; assert(false);
    }

    #insert,scope() deferred;
}

semantic_error :: (ast: *Ast_Node, report: string, format: .. Any) {
    print("\nError: %\n", tprint(report, .. format));

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

    return tprint("(line %): %[31m%[0m%", loc.line, first, second, third);
}