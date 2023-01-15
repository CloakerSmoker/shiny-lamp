class ExpressionNode
    getter context : SourceContext

    def initialize(@context)
    end
end

class BinaryExpression < ExpressionNode
    getter left : ExpressionNode
    getter operator : SymbolToken
    getter right : ExpressionNode

    def initialize(@left, @operator, @right)
        super(SourceContext.new(@left.context, @operator.context, @right.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)| 
            if value == @operator.value
                io << "(" << @left << " " << symbol << " " << @right << ")"
            end
        end
    end
end

class UnaryPrefixExpression < ExpressionNode
    getter operator : SymbolToken
    getter operand : ExpressionNode

    def initialize(@operator, @operand)
        super(SourceContext.new(@operator.context, @operand.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)| 
            if value == @operator.value
                io << "(" << symbol << " " << @operand << ")"
            end
        end
    end
end

class UnarySuffixExpression < ExpressionNode
    getter operand : ExpressionNode
    getter operator : SymbolToken

    def initialize(@operand, @operator)
        super(SourceContext.new(@operand.context, @operator.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)|
            if value == @operator.value
                io << "(" << @operand  << " " << symbol << ")"
            end
        end
    end
end

class IntegerExpression < ExpressionNode
    getter token : IntegerToken
    getter value : Int32

    def initialize(@token)
        @value = @token.value
        super(@token.context)
    end

    def to_s(io)
        io << @value
    end
end

class IdentifierExpression < ExpressionNode
    getter token : IdentifierToken
    getter value : String

    def initialize(@token)
        @value = @token.value
        super(@token.context)
    end

    def to_s(io)
        io << @value
    end
end

class CallExpression < ExpressionNode
    getter target : ExpressionNode
    getter parameters : Array(ExpressionNode)

    def initialize(@target, @parameters)
        super(target.context)
    end

    def to_s(io)
        io << "(" << @target << ")("
        @parameters.join(io, ", ")
        io << ")"
    end
end

class TernaryExpression < ExpressionNode
    getter condition : ExpressionNode
    getter left : ExpressionNode
    getter right : ExpressionNode

    def initialize(@condition, @left, @right)
        super(SourceContext.new(@condition.context, @left.context, @right.context))
    end

    def to_s(io)
        io << "(" << @condition << " ? " << @left << " : " << @right << ")"
    end
end

class AnonymousFunctionExpression < ExpressionNode
    getter name : IdentifierToken | Nil
    getter parameters : Array(IdentifierExpression)

    getter body : ExpressionNode
    
    def initialize(@name, @parameters, @body)
        super(@body.context)
    end

    def to_s(io)
        if name
            io << @name
        end

        io << "("
        @parameters.join(io, ", ")
        io << ") => " << @body
    end
end