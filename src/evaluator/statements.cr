
class ContinueException < Exception
end

class BreakException < Exception
end

class Evaluator
    def evaluate_function_definition(definition : FunctionDefinintion)
        function = UserFunction.new(definition)

        @current_environment.set_local(definition.name.value, function)
    end

    def evaluate_return(return_ : ReturnStatement)
        # funky name since "return" is a keyword

        result = nil

        if return_.value
            result = evaluate_expression(return_.value.as(ExpressionNode))
        end

        raise ReturnException.new(result)
    end

    def evaluate_loop(loop_ : LoopStatement)
        count = -1

        if loop_.count
            count = evaluate_expression_typed(loop_.count.as(ExpressionNode), IntegerValue).value
        end

        index = 1

        while index != count
            @current_environment.set("A_Index", IntegerValue.new(index))
            index += 1

            begin
                evaluate_block(loop_.body)
            rescue ContinueException
                # pass
            rescue BreakException
                break
            end

            if loop_.postcondition
                postcondition = evaluate_expression(loop_.postcondition.as(ExpressionNode))

                break if postcondition.truthy?
            end
        end

        @current_environment.unset("A_Index")
    end

    def evaluate_while_loop(while_ : WhileLoopStatement)
        index = 1

        loop do
            @current_environment.set("A_Index", IntegerValue.new(index))

            condition = evaluate_expression(while_.condition)

            break if !condition.truthy?

            begin
                evaluate_block(while_.body)
            rescue ContinueException
                # pass
            rescue BreakException
                break
            end
        end

        @current_environment.unset("A_Index")
    end

    def evaluate_if(if_ : IfStatement)
        if_.branches.each do |(condition, body)|
            if evaluate_expression(condition).truthy?
                evaluate_block(body)
                return
            end
        end

        if if_.else_branch
            evaluate_block(if_.else_branch.as(Block))
        end
    end

    def evaluate_switch(switch : SwitchStatement)
        switch_value = evaluate_expression(switch.value)

        switch.cases.each do |(values, body)|
            values.each do |case_value_node|
                case_value = evaluate_expression(case_value_node)

                if value_equals?(switch_value, case_value)
                    evaluate_block(body)
                    return
                end
            end
        end

        if switch.default_case
            evaluate_block(switch.default_case.as(Block))
        end
    end

    def evaluate_statement(statement : StatementNode)
        case statement
        when .is_a?(ExpressionStatement)
            value = evaluate_expression(statement.as(ExpressionStatement).value)

            #puts "#{statement.as(ExpressionStatement).value}: #{value}"
        when .is_a?(FunctionDefinintion)
            evaluate_function_definition(statement.as(FunctionDefinintion))
        when .is_a?(ReturnStatement)
            evaluate_return(statement.as(ReturnStatement))
        when .is_a?(LoopStatement)
            evaluate_loop(statement.as(LoopStatement))
        when .is_a?(WhileLoopStatement)
            evaluate_while_loop(statement.as(WhileLoopStatement))
        when .is_a?(ContinueStatement)
            raise ContinueException.new()
        when .is_a?(BreakStatement)
            raise BreakException.new()
        when .is_a?(IfStatement)
            evaluate_if(statement.as(IfStatement))
        when .is_a?(SwitchStatement)
            evaluate_switch(statement.as(SwitchStatement))
        end
    end

    def evaluate_block(block : Block)
        block.statements.each do |statement|
            evaluate_statement(statement)
        end
    end
end