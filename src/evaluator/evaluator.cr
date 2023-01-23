require "./values.cr"
require "./expressions.cr"
require "./statements.cr"

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

    def unset(name : String)
        container = self

        if existing = lookup(name)
            container.variables.delete(name)
        end
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
end