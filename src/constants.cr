enum Marker
    ColonEquals
    PlusEquals
    MinusEquals
    StarEquals
    SlashEquals
    SlashSlashEquals
    DotEquals
    OrEquals
    AndEquals
    XorEquals
    RightShiftEquals
    LeftShiftEquals
    RightRotateEquals
    
    QuestionMark
    Colon

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

    FatArrow
end

Symbols = [

    {":=", Marker::ColonEquals},
    {"+=", Marker::PlusEquals},
    {"-=", Marker::MinusEquals},
    {"*=", Marker::StarEquals},
    {"/=", Marker::SlashEquals},
    {"//=", Marker::SlashSlashEquals},
    {".=", Marker::DotEquals},
    {"|=", Marker::OrEquals},
    {"&=", Marker::AndEquals},
    {"^=", Marker::XorEquals},
    {">>=", Marker::RightShiftEquals},
    {"<<=", Marker::LeftShiftEquals},
    {">>>=", Marker::RightRotateEquals},

    {"?", Marker::QuestionMark},
    {":", Marker::Colon},

    {"+", Marker::Plus},
    {"-", Marker::Minus},
    {"*", Marker::Times},
    {"/", Marker::Divide},

    {".", Marker::Dot},
    {"%", Marker::Substitution},

    {"[", Marker::OpenIndex},
    {"]", Marker::CloseIndex},

    {"=>", Marker::FatArrow},

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
    Marker::PlusEquals => { 1, Associativity::Right },
    Marker::MinusEquals => { 1, Associativity::Right },
    Marker::StarEquals => { 1, Associativity::Right },
    Marker::SlashEquals => { 1, Associativity::Right },
    Marker::SlashSlashEquals => { 1, Associativity::Right },
    Marker::DotEquals => { 1, Associativity::Right },
    Marker::OrEquals => { 1, Associativity::Right },
    Marker::AndEquals => { 1, Associativity::Right },
    Marker::XorEquals => { 1, Associativity::Right },
    Marker::RightShiftEquals => { 1, Associativity::Right },
    Marker::LeftShiftEquals => { 1, Associativity::Right },
    Marker::RightRotateEquals => { 1, Associativity::Right },

    Marker::QuestionMark => { 2, Associativity::Right },

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