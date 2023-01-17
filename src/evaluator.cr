
abstract class EvaluatorValue
    abstract def truthy?
end

class StringValue < EvaluatorValue
    getter value : String

    def initialize(@value)
    end

    def truthy?
        return @value.size != 0
    end

    def to_s(io)
        io << "\"" << @value << "\""
    end
end

class IntegerValue < EvaluatorValue
    getter value : Int32

    def initialize(@value)
    end

    def truthy?
        return @value != 0
    end

    def to_s(io)
        io << @value
    end
end

class ObjectValue < EvaluatorValue
    getter values : Hash(EvaluatorValue, EvaluatorValue)

    def initialize
        @values = {} of EvaluatorValue => EvaluatorValue
    end

    def truthy?
        return true
    end

    def has_key?(name : EvaluatorValue)
        return @values.has_key?(name)
    end

    def []?(name : EvaluatorValue)
        return @values[name]?
    end

    def []=(name : EvaluatorValue, value : EvaluatorValue)
        @values[name] = value
    end
end

class Environment
    getter variables = {} of String => EvaluatorValue

    def lookup(name : String) : EvaluatorValue | Nil
        return @variables[name]?
    end

    def set(name : String, value : EvaluatorValue)
        @variables[name] = value
    end
end

class Evaluator

    getter global_environment : Environment
    getter current_environment : Environment

    def initialize
        @global_environment = Environment.new()

        @current_environment = @global_environment
    end

    def evaluate_identifer(expression : IdentifierExpression) : EvaluatorValue
        if value = @current_environment.lookup(expression.value)
            return value.as(EvaluatorValue)
        end

        raise Exception.new("Unset variable: #{expression}")
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
            raise Exception.new("Bad result type for expression: #{expression}, expected #{{{value_type}}}, got #{typeof(%result)}")
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

    def evaluate_expression(expression : ExpressionNode) : EvaluatorValue
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
        end

        raise Exception.new("Unimplemented expression type: #{expression}")
    end

    def evaluate_statement(statement : StatementNode)
        case statement
        when .is_a?(ExpressionStatement)
            evaluate_expression(statement.as(ExpressionStatement).value)
        end
    end

    def evaluate_block(block : Block)
        block.statements.each do |statement|
            evaluate_statement(statement)
        end
    end

end