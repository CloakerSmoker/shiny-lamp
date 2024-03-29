class Evaluator
    def evaluate_identifer(expression : IdentifierExpression) : EvaluatorValue
        if value = @current_environment.get(expression.value)
            return value
        end

        expression.error("Unset variable")
    end

    def evaluate_string(expression : StringExpression) : EvaluatorValue
        return StringValue.new(expression.value)
    end

    def evaluate_integer(expression : IntegerExpression) : EvaluatorValue
        return IntegerValue.new(expression.value)
    end

    def evaluate_prefix(expression : UnaryPrefixExpression) : EvaluatorValue
        case expression.operator.value
        when .low_not?, .not?
            operand_value = evaluate_expression(expression.operand)

            return IntegerValue.new(operand_value.truthy? ? 0 : 1)
        when .plus?
            return evaluate_expression(expression.operand)
        when .minus?
            operand_integer = evaluate_expression_typed(expression.operand, IntegerValue)

            return IntegerValue.new(-operand_integer.as(IntegerValue).value)
        when .bitwise_not?
            operand_integer = evaluate_expression_typed(expression.operand, IntegerValue)

            return IntegerValue.new(~operand_integer.as(IntegerValue).value)
        end

        raise Exception.new("Unimplemented prefix operator: #{expression.operator}")
    end

    def evaluate_suffix(expression : UnarySuffixExpression) : EvaluatorValue
        raise Exception.new("Unimplemented suffix operator: #{expression.operator}")
    end

    def ensure_value_is_string(value : EvaluatorValue) : StringValue
        if !value.is_a?(StringValue)
            return StringValue.new("#{value}")
        end

        return value.as(StringValue)
    end

    macro evaluate_expression_typed(expression, value_type)
        if (%result = evaluate_expression({{expression}})).is_a?({{value_type}})
            %result.as({{value_type}})
        else
            raise SourceException.new({{expression}}.context, "Bad result type for expression, expected #{{{value_type}}}, got #{typeof(%result)}")
        end
    end

    macro binary_integer_op(result)
        left = evaluate_expression_typed(expression.left, IntegerValue).value
        right = evaluate_expression_typed(expression.right, IntegerValue).value

        return IntegerValue.new(({{result}}).to_i())
    end

    macro binary_string_op(result)
        left = ensure_value_is_string(evaluate_expression(expression.left)).value
        right = ensure_value_is_string(evaluate_expression(expression.right)).value

        return StringValue.new({{result}})
    end

    def evaluate_assignment(target : ExpressionNode, value : EvaluatorValue) : EvaluatorValue

        case target
        when .is_a?(BinaryExpression)
            # todo
        when .is_a?(IdentifierExpression)
            target_name = target.as(IdentifierExpression).value

            current_environment.set(target_name, value)
        end

        return value
    end

    def evaluate_binary(expression : BinaryExpression) : EvaluatorValue
        case expression.operator.value
        when .dot?
            name = expression.right.as(IdentifierExpression).value

            object = evaluate_expression_typed(expression.left, ObjectValue)

            return object.get(self, expression, name)
        when .plus?
            binary_integer_op(left + right)
        when .minus?
            binary_integer_op(left - right)
        when .times?
            binary_integer_op(left * right)
        when .divide?
            binary_integer_op(left / right)
        when .floor_divide?
            binary_integer_op(left // right)
        when .power?
            binary_integer_op(left ** right)
        when .concatinate?
            binary_string_op("#{left}#{right}")
        when .colon_equals?
            return evaluate_assignment(expression.left, evaluate_expression(expression.right))

        end

        raise Exception.new("Unimplemented binary operator: #{expression.operator}")
    end

    def evaluate_group(expression : GroupExpression) : EvaluatorValue
        expression.expressions.each_with_index do |child, index|
            value = evaluate_expression(child)

            return value if index == expression.expressions.size - 1
        end

        # unreachable, but makes the compiler happy

        return IntegerValue.new(0)
    end

    def evaluate_call(expression : CallExpression) : EvaluatorValue
        parameters = [] of EvaluatorValue

        if expression.target.is_a?(BinaryExpression) && expression.target.as(BinaryExpression).operator.value.dot?
            access = expression.target.as(BinaryExpression)

            object = evaluate_expression_typed(access.left, ObjectValue)
            name = access.right.as(IdentifierExpression).value

            target = object.get_callable(self, expression, name)

            # prepend the `this` parameter

            parameters << object
        else
            target = evaluate_expression_typed(expression.target, Callable)
        end

        expression.parameters.each do |parameter|
            parameters << evaluate_expression(parameter)
        end

        return target.call(self, expression, parameters)
    end

    def evaluate_array_literal(expression : ArrayLiteralExpression)

    end

    def evaluate_object_literal(expression : ObjectLiteralExpression)
        result = ObjectValue.new()

        expression.values.each do |(key_node, value_node)|
            key = evaluate_expression_typed(key_node, StringValue)
            value = evaluate_expression(value_node)

            result.define_static_property(key.value, value)
        end

        return result
    end

    def evaluate_anonymous_function(expression : AnonymousFunctionExpression)
        function = UserFunction.new(expression)

        if expression.name != nil
            @current_environment.set_local(expression.name.as(IdentifierToken).value, function)
        end

        return function
    end

    def evaluate_expression(expression : ExpressionNode) : EvaluatorValue
        expression.notify("hi!")

        case expression
        when .is_a?(IdentifierExpression)
            return evaluate_identifer(expression.as(IdentifierExpression))
        when .is_a?(StringExpression)
            return evaluate_string(expression.as(StringExpression))
        when .is_a?(IntegerExpression)
            return evaluate_integer(expression.as(IntegerExpression))
        when .is_a?(UnaryPrefixExpression)
            return evaluate_prefix(expression.as(UnaryPrefixExpression))
        when .is_a?(UnarySuffixExpression)
            return evaluate_suffix(expression.as(UnarySuffixExpression))
        when .is_a?(BinaryExpression)
            return evaluate_binary(expression.as(BinaryExpression))
        when .is_a?(GroupExpression)
            return evaluate_group(expression.as(GroupExpression))
        when .is_a?(CallExpression)
            return evaluate_call(expression.as(CallExpression))
        when .is_a?(AnonymousFunctionExpression)
            return evaluate_anonymous_function(expression.as(AnonymousFunctionExpression))
        when .is_a?(ObjectLiteralExpression)
            return evaluate_object_literal(expression.as(ObjectLiteralExpression))
        end

        raise Exception.new("Unimplemented expression type: #{expression}")
    end
end