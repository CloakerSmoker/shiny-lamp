
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

class UnsetValue < EvaluatorValue
    def truthy?
        return false
    end

    def to_s(io)
        io << "unset"
    end
end

abstract class Callable < EvaluatorValue
    abstract def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(ExpressionNode)) : EvaluatorValue
end

class NativeFunction < Callable
    getter callback : (Evaluator, SourceElement, Array(ExpressionNode)) -> EvaluatorValue

    def initialize(@callback : (Evaluator, SourceElement, Array(ExpressionNode)) -> EvaluatorValue)
    end

    def truthy?
        return true
    end

    def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(ExpressionNode)) : EvaluatorValue
        return callback.call(evaluator, blame, parameters)
    end
end

class UserFunction < Callable
    getter anonymous : AnonymousFunctionExpression

    def initialize(@anonymous)
    end

    def truthy?
        return true
    end

    def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(ExpressionNode)) : EvaluatorValue
        if parameters.size != @anonymous.parameters.size
            blame.error("Wrong number of parameters passed to function, expected #{@anonymous.parameters.size}, got #{parameters.size}")
        end

        environment = evaluator.push_environment()

        parameters.each_with_index do |parameter, index|
            formal_parameter = @anonymous.parameters[index]
            formal_parameter_name = formal_parameter.value
            
            parameter_value = evaluator.evaluate_expression(parameter)

            environment.set_local(formal_parameter_name, parameter_value)
        end

        result = evaluator.evaluate_expression(@anonymous.body)

        evaluator.pop_environment()

        return result
    end

    def to_s(io)
        io << "anonymous_function(#{@anonymous})"
    end
end

#class PropertyValue < EvaluatorValue

class ObjectValue < EvaluatorValue
    getter properties = {} of EvaluatorValue => EvaluatorValue

    def truthy?
        return true
    end

    def has_key?(name : EvaluatorValue)
        return @properties.has_key?(name)
    end

    def define_property()
    end

    #abstract def set_item(key : EvaluatorValue, value : EvaluatorValue)
    #abstract def get_item(key : EvaluatorValue) : EvaluatorValue
end

class ArrayValue < ObjectValue
    getter elements = [] of EvaluatorValue

    def initialize
    end

    
end

class Environment
    getter parent : Environment | Nil = nil
    getter variables = {} of String => EvaluatorValue

    def initialize
    end
    
    def initialize(@parent)
    end

    def lookup(name : String) : Tuple(Environment, EvaluatorValue) | Nil
        if value = @variables[name]?
            return {self, value}
        else
            if @parent
                return @parent.as(Environment).lookup(name)
            else
                return nil
            end
        end
    end

    def get(name : String) : EvaluatorValue | Nil
        if results = lookup(name)
            return results[1]
        else
            return nil
        end
    end

    def set_local(name : String, value : EvaluatorValue)
        @variables[name] = value
    end

    def set(name : String, value : EvaluatorValue)
        container = self

        if existing = lookup(name)
            container = existing[0]
        end

        container.set_local(name, value)
    end

    def enter
        return Environment.new(self)
    end

    def leave
        return @parent.as(Environment)
    end
end

class Evaluator
    getter global_environment : Environment
    
    getter current_environment : Environment

    def push_environment
        @current_environment = @current_environment.enter()

        return @current_environment
    end
    def pop_environment
        @current_environment = @current_environment.leave()

        return @current_environment
    end

    def puts_fn(evaluator : Evaluator, blame : SourceElement, parameters : Array(ExpressionNode)) : EvaluatorValue
        parameters.each do |parameter|
            puts "#{parameter}: #{evaluate_expression(parameter)}"
        end

        return UnsetValue.new().as(EvaluatorValue)
    end

    def initialize
        @global_environment = Environment.new()

        @current_environment = @global_environment

        @current_environment.set("puts", NativeFunction.new(->puts_fn(Evaluator, SourceElement, Array(ExpressionNode))))
    end

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
        target = evaluate_expression_typed(expression.target, Callable)

        puts "Call to #{target}"

        return target.call(self, expression, expression.parameters)
    end

    def evaluate_array_literal(expression : ArrayLiteralExpression)

    end

    def evaluate_object_literal(expression : ObjectLiteralExpression)

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
        end

        raise Exception.new("Unimplemented expression type: #{expression}")
    end

    def evaluate_statement(statement : StatementNode)
        case statement
        when .is_a?(ExpressionStatement)
            value = evaluate_expression(statement.as(ExpressionStatement).value)

            #puts "#{statement.as(ExpressionStatement).value}: #{value}"
        end
    end

    def evaluate_block(block : Block)
        block.statements.each do |statement|
            evaluate_statement(statement)
        end
    end

end