enum Marker
    ColonEquals
    PlusEquals
    Plus
    Minus
    Times
    Divide

    Dot
    Substitution
    
    PlusPlus
    MinusMinus
    
    Comma
    OpenParen
    CloseParen
    
    OpenIndex
    CloseIndex
end

Symbols = [
    {":=", Marker::ColonEquals},
    {"+=", Marker::PlusEquals},
    {"+", Marker::Plus},
    {"-", Marker::Minus},
    {"*", Marker::Times},
    {"/", Marker::Divide},

    {".", Marker::Dot},
    {"%", Marker::Substitution},

    {"[", Marker::OpenIndex},
    {"]", Marker::CloseIndex},

    {"++", Marker::PlusPlus},
    {"--", Marker::MinusMinus},

    {",", Marker::Comma},
    {"(", Marker::OpenParen},
    {")", Marker::CloseParen}
]

enum Associativity
    Left
    Right
end

BinaryOperators = {
    Marker::ColonEquals => { 1, Associativity::Right },
    Marker::Plus => { 2, Associativity::Left },
    Marker::Minus => { 2, Associativity::Left },
    Marker::Dot => { 11, Associativity::Left }
}

PrefixOperators = {
    Marker::Minus => 3,
    Marker::PlusPlus => 10,
    Marker::MinusMinus => 10
}

SuffixOperators = {
    Marker::PlusPlus => 10,
    Marker::MinusMinus => 10,
    Marker::OpenParen => 11,
    Marker::OpenIndex => 12
}