
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
    abstract def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue
end

class NativeFunction < Callable
    getter callback : (Evaluator, SourceElement, Array(EvaluatorValue)) -> EvaluatorValue

    def initialize(@callback : (Evaluator, SourceElement, Array(EvaluatorValue)) -> EvaluatorValue)
    end

    def truthy?
        return true
    end

    def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue
        return callback.call(evaluator, blame, parameters)
    end
end

class ReturnException < Exception
    getter value : EvaluatorValue | Nil

    def initialize(@value)
    end
end

class UserFunction < Callable
    getter function : AnonymousFunctionExpression | FunctionDefinintion

    def initialize(@function)
    end

    def truthy?
        return true
    end

    def call(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue
        if parameters.size != @function.parameters.size
            blame.error("Wrong number of parameters passed to function, expected #{@function.parameters.size}, got #{parameters.size}")
        end

        environment = evaluator.push_environment()

        parameters.each_with_index do |parameter, index|
            formal_parameter = @function.parameters[index]
            formal_parameter_name = formal_parameter.value

            environment.set_local(formal_parameter_name, parameter)
        end

        result = nil

        if @function.is_a?(AnonymousFunctionExpression)
            result = evaluator.evaluate_expression(@function.body.as(ExpressionNode))
        elsif @function.is_a?(FunctionDefinintion)
            begin
                evaluator.evaluate_block(@function.body.as(Block))
            rescue exception : ReturnException
                result = exception.value
            end
        end

        evaluator.pop_environment()

        return result.as(EvaluatorValue) if result != nil
        return UnsetValue.new()
    end

    def to_s(io)
        io << "function<#{@function}>"
    end
end

class DynamicProperty
    property do_get : Callable | Nil = nil
    property do_set : Callable | Nil = nil
    property do_call : Callable | Nil = nil
end

class ObjectValue < EvaluatorValue
    getter properties = {} of String => EvaluatorValue | DynamicProperty

    def truthy?
        return true
    end

    def has_key?(name : String)
        return @properties.has_key?(name)
    end

    def get(evaluator : Evaluator, blame : SourceElement, name : String) : EvaluatorValue
        if property = @properties[name]?
            if property.is_a?(DynamicProperty)
                dynamic = property.as(DynamicProperty)

                if dynamic.do_get
                    return dynamic.do_get.as(Callable).call(evaluator, blame, [self] of EvaluatorValue)
                elsif dynamic.do_call
                    return dynamic.do_call.as(Callable).call(evaluator, blame, [self] of EvaluatorValue)
                else
                    blame.error("Dynamic property does not define 'get'")
                end
            else
                return property.as(EvaluatorValue)
            end
        end

        blame.error("Undefined property")
    end

    def set(evaluator : Evaluator, blame : SourceElement, name : String, value : EvaluatorValue)
        if property = @properties[name]?
            if property.is_a?(DynamicProperty)
                dynamic = property.as(DynamicProperty)

                if dynamic.do_set
                    dynamic.do_set.as(Callable).call(evaluator, blame, [self, value] of EvaluatorValue)
                else
                    blame.error("Dynamic property does not define 'get'")
                end
            else
                @properties[name] = value
            end
        end

        blame.error("Undefined property")
    end

    def get_callable(evaluator : Evaluator, blame : SourceElement, name : String) : Callable
        if property = @properties[name]?
            if property.is_a?(DynamicProperty)
                dynamic = property.as(DynamicProperty)

                if dynamic.do_call
                    return dynamic.do_call.as(Callable)
                elsif dynamic.do_get
                    return dynamic.do_get.as(Callable).call(evaluator, blame, [self] of EvaluatorValue).as(Callable)
                else
                    blame.error("Dynamic property does not define 'get' while attempting to 'call' the property")
                end
            else
                return property.as(Callable)
            end
        end

        blame.error("Undefined property")
    end

    def define_static_property(name : String, value : EvaluatorValue)
        @properties[name] = value
    end

    def define_dynamic_property(name : String, blame : SourceElement, descriptor : ObjectValue)
        get = descriptor.properties["get"]?
        set = descriptor.properties["set"]?
        call = descriptor.properties["call"]?

        value = descriptor.properties["value"]?

        if value
            define_static_property(name, value.as(EvaluatorValue))
        else
            property = DynamicProperty.new()

            if get
                blame.error("'Get' accessor must be callable") if !get.is_a?(Callable)
                property.do_get = get.as(Callable)
            end

            if set
                blame.error("'Set' accessor must be callable") if !set.is_a?(Callable)
                property.do_set = set.as(Callable)
            end

            if call
                blame.error("'Call' accessor must be callable") if !call.is_a?(Callable)
                property.do_call = call.as(Callable)
            end
            
            @properties[name] = property
        end
    end

    def do_method_get(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue

    end

    def define_method(name : String, target : Callable)
        property = DynamicProperty.new()

        property.do_call = target
        property.do_get = NativeFunction.new(
            ->(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue {
                return target
            }
        )

        @properties[name] = property
    end

    def do_define_property(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue
        blame.error("Incorrect number of parameters passed to function") if parameters.size != 3

        blame.error("'this' parameter must be an object") if !parameters[0].is_a?(ObjectValue)
        blame.error("First parameter must be a property name") if !parameters[1].is_a?(StringValue)
        blame.error("Second property must be a property descriptor") if !parameters[2].is_a?(ObjectValue)

        this = parameters[0].as(ObjectValue)
        name = parameters[1].as(StringValue).value
        descriptor = parameters[2].as(ObjectValue)

        this.define_dynamic_property(name, blame, descriptor)

        return this.as(EvaluatorValue)
    end

    def initialize
        define_property_fn = NativeFunction.new(->do_define_property(Evaluator, SourceElement, Array(EvaluatorValue)))

        define_method("DefineProp", define_property_fn)

    end

    #abstract def set_item(key : EvaluatorValue, value : EvaluatorValue)
    #abstract def get_item(key : EvaluatorValue) : EvaluatorValue
end

class ArrayValue < ObjectValue
    getter elements = [] of EvaluatorValue

    def initialize
    end

    def initialize(@elements)
    end

    def truthy?
        return true
    end

    def push(value : EvaluatorValue)
        @elements << value
    end

    def length
        return @elements.size
    end

    def at(index : Int32)
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

    def puts_fn(evaluator : Evaluator, blame : SourceElement, parameters : Array(EvaluatorValue)) : EvaluatorValue
        parameters.each do |parameter|
            puts "#{parameter}"
        end

        return UnsetValue.new().as(EvaluatorValue)
    end

    def initialize
        @global_environment = Environment.new()

        @current_environment = @global_environment

        @current_environment.set("puts", NativeFunction.new(->puts_fn(Evaluator, SourceElement, Array(EvaluatorValue))))
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