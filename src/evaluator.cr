
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
end

class Environment
    getter variables : ObjectValue = ObjectValue.new()

    def lookup(name : String)
        return IntegerValue.new(0)
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
        return @current_environment.lookup(expression.value)
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

    def evaluate_binary(expression : BinaryExpression) : EvaluatorValue
        case expression.operator.value
        when .plus?
            left = evaluate_expression_typed(expression.left, IntegerValue)
            right = evaluate_expression_typed(expression.right, IntegerValue)

            return IntegerValue.new(left + right)
        when .minus?
            left = evaluate_expression_typed(expression.left, IntegerValue)
            right = evaluate_expression_typed(expression.right, IntegerValue)

            return IntegerValue.new(left - right)

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

    def evaluate_expression_typed(expression : ExpressionNode, value_type : T.class) forall T
        result = evaluate_expression(expression)

        begin
            return result
        rescue
            raise Exception.new("Bad result type for expression: #{expression}, expected #{value_type}, got #{typeof(value_type)}")
        end
    end

    #def evaluate_statement(statement : StatementNode)
        #case statement
        #when .is_a?(ExpressionStatement)
            
    #end

end