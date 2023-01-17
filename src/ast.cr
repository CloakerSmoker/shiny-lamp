def indent(io, level)
    while level != 0
        io << "\t"
        level -= 1
    end
end

class StatementNode
    getter context : SourceContext

    def initialize(@context)
    end

    def to_s_indent(io, indent)
    end
end

class ExpressionStatement < StatementNode
    getter value : ExpressionNode

    def initialize(@value)
        super(@value.context)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << value << "\n"
    end
end

class Block
    getter statements : Array(StatementNode)

    def initialize(@statements)
    end

    def to_s_indent(io, level)
        io << "{\n"

        @statements.each do |statement|
            statement.to_s_indent(io, level + 1)
        end

        indent(io, level)
        io << "}\n"
    end
end

class IfStatement < StatementNode
    getter branches : Array(Tuple(ExpressionNode, Block))
    getter else_branch : Block | Nil

    def initialize(@branches, @else_branch)
        super(@branches[0][0].context)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "if " << @branches[0][0] << " "
        branches[0][1].to_s_indent(io, level)

        @branches.each_with_index do |(condition, body), index|
            next if index == 0

            indent(io, level)
            io << "else if " << condition << " "
            body.to_s_indent(io, level)
        end

        if @else_branch != nil
            indent(io, level)
            io << "else "
            @else_branch.as(Block).to_s_indent(io, level)
        end

    end
end


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

class StringExpression < ExpressionNode
    getter token : StringToken
    getter value : String

    def initialize(@token)
        @value = @token.value
        super(@token.context)
    end

    def to_s(io)
        io << '"' << @value << '"'
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

class ArrayLiteralExpression < ExpressionNode
    getter values : Array(ExpressionNode)

    def initialize(@values)
        super(@values[0].context)
    end

    def to_s(io)
        io << "["

        @values.each_with_index do |value, index|
            io << ", " if index != 0

            io << value
        end

        io << "]"
    end
end

class ObjectLiteralExpression < ExpressionNode
    getter values : Array(Tuple(ExpressionNode, ExpressionNode))

    def initialize(@values)
        super(@values[0][0].context)
    end

    def to_s(io)
        io << "{"

        @values.each_with_index do |(key, value), index|
            io << ", " if index != 0

            io << key << ": " << value
        end

        io << "}"
    end
end

class GroupExpression < ExpressionNode
    getter expressions : Array(ExpressionNode)

    def initialize(@expressions)
        super(@expressions[0].context)
    end

    def to_s(io)
        io << "("

        @expressions.each_with_index do |expression, index|
            io << ", " if index != 0

            io << expression
        end

        io << ")"
    end
end