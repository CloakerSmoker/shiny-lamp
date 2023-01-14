enum Operator
    ColonEquals
    PlusEquals
    Plus
    Minus
    Times
    Divide
end

enum Punctuation
    Comma
    OpenParen
    CloseParen
end

Symbols = [
    {":=", Operator::ColonEquals},
    {"+=", Operator::PlusEquals},
    {"+", Operator::Plus},
    {"-", Operator::Minus},
    {"*", Operator::Times},
    {"/", Operator::Divide},

    {",", Punctuation::Comma},
    {"(", Punctuation::OpenParen},
    {")", Punctuation::CloseParen}
]

enum Associativity
    Left
    Right
end

BinaryOperators = {
    Operator::ColonEquals => { 1, Associativity::Right },
    Operator::Plus => { 2, Associativity::Left },
    Operator::Minus => { 2, Associativity::Left }
}

PrefixOperators = {
    Operator::Minus => 3
}

SuffixOperators = {

} of Operator => Int32