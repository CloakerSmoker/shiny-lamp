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
            count = evaluate_expression(loop_.count.as(ExpressionNode))
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
        end
    end

    def evaluate_block(block : Block)
        block.statements.each do |statement|
            evaluate_statement(statement)
        end
    end
end