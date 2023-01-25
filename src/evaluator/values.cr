abstract class EvaluatorValue
    abstract def truthy?
end

class Evaluator
    def value_equals?(left : EvaluatorValue, right : EvaluatorValue)
        return "#{left}" == "#{right}"
    end
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
        environment = evaluator.push_environment()

        @function.parameters.each_with_index do |formal_parameter, index|
            case formal_parameter
            when .is_a?(OptionalParameter)
                optional = formal_parameter.as(OptionalParameter)

                if index > parameters.size
                    if optional.default_value
                        value = evaluator.evaluate_expression(optional.default_value.as(ExpressionNode))
                    else
                        value = UnsetValue.new()
                    end
                else
                    value = parameters[index]
                end

                environment.set_local(optional.name.value, value)
            when .is_a?(ReferenceParameter)
                # TODO
            when .is_a?(OptionalReferenceParameter)
                # TODO
            when .is_a?(VariadicParameter)
                variadic = formal_parameter.as(VariadicParameter)

                if variadic.name
                    value = ArrayValue.new(parameters[index..])

                    environment.set_local(variadic.name.as(IdentifierExpression).value, value)
                end
            when .is_a?(NamedParameter)
                if index > parameters.size
                    blame.error("Not enough parameters passed to function")
                end

                named = formal_parameter.as(NamedParameter)

                environment.set_local(named.name.value, parameters[index])
            end
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
    
    def to_s(io)
        io << "["

        @elements.each_with_index do |value, index|
            io << ", " if index != 0

            io << value
        end

        io << "]"
    end
end