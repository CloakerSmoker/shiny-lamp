enum Keyword
    If
    Else

    Loop
    Continue
    Break
end

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

    OrMaybe

    LogicalOr
    LogicalAnd

    LowNot

    Is
    In
    Contains

    Equals
    EqualsEquals
    NotEquals
    NotEqualsEquals

    Less
    LessEquals
    Greater
    GreaterEquals

    Concatinate

    And
    BitwiseOr
    BitwiseXor

    LeftShift
    RightShift
    RightRotate

    Plus
    Minus

    Times
    Divide
    FloorDivide

    Not
    BitwiseNot
    # BitwiseAnd is already defined as 'And' for references AND bitwise

    Power

    PlusPlus
    MinusMinus

    Maybe

    Dot
    OpenIndex
    CloseIndex

    Substitution
    
    Comma
    OpenParen
    CloseParen

    OpenBracket
    CloseBracket

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

    {"??", Marker::OrMaybe},

    {"||", Marker::LogicalOr},
    {"&&", Marker::LogicalAnd},

    # dummies for printing, actually defined as KeywordSymbols
    {"not", Marker::LowNot},
    {"is", Marker::Is},
    {"in", Marker::In},
    {"contains", Marker::Contains},
    
    {"=", Marker::Equals},
    {"==", Marker::EqualsEquals},
    {"!=", Marker::NotEquals},
    {"!==", Marker::NotEqualsEquals},

    {"<", Marker::Less},
    {"<=", Marker::LessEquals},
    {">", Marker::Greater},
    {">=", Marker::GreaterEquals},

    # also " . " hardwired into the tokenizer
    {"..", Marker::Concatinate},

    {"&", Marker::And},
    {"|", Marker::BitwiseOr},
    {"^", Marker::BitwiseXor},

    {"<<", Marker::LeftShift},
    {">>", Marker::RightShift},
    {">>>", Marker::RightRotate},

    {"+", Marker::Plus},
    {"-", Marker::Minus},

    {"*", Marker::Times},
    {"/", Marker::Divide},
    {"//", Marker::FloorDivide},

    {"!", Marker::Not},
    {"~", Marker::BitwiseNot},
    # '&' alright defined

    {"**", Marker::Power},

    {"++", Marker::PlusPlus},
    {"--", Marker::MinusMinus},

    {"_?", Marker::Maybe},

    {".", Marker::Dot},

    {"%", Marker::Substitution},

    {"[", Marker::OpenIndex},
    {"]", Marker::CloseIndex},

    {"=>", Marker::FatArrow},

    {",", Marker::Comma},
    {"(", Marker::OpenParen},
    {")", Marker::CloseParen},

    {"{", Marker::OpenBracket},
    {"}", Marker::CloseBracket}
]

KeywordSymbols = {
    "or" => Marker::LogicalOr,
    "and" => Marker::LogicalAnd,
    "not" => Marker::LowNot,
    "is" => Marker::Is,
    "in" => Marker::In,
    "contains" => Marker::Contains
}

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

    Marker::OrMaybe => { 3, Associativity::Left },

    Marker::LogicalOr => { 4, Associativity::Left },

    Marker::LogicalAnd => { 5, Associativity::Left },

    # 6 for LowNot

    Marker::Is => { 7, Associativity::Left },
    Marker::In => { 7, Associativity::Left },
    Marker::Contains => { 7, Associativity::Left },

    Marker::Equals => { 8, Associativity::Right },
    Marker::EqualsEquals => { 8, Associativity::Right },
    Marker::NotEquals => { 8, Associativity::Right },
    Marker::NotEqualsEquals => { 8, Associativity::Right },

    Marker::Less => { 9, Associativity::Left },
    Marker::LessEquals => { 9, Associativity::Left },
    Marker::Greater => { 9, Associativity::Left },
    Marker::GreaterEquals => { 9, Associativity::Left },

    Marker::Concatinate => { 10, Associativity::Left },

    Marker::And => { 11, Associativity::Left },
    Marker::BitwiseOr => { 11, Associativity::Left },
    Marker::BitwiseXor => { 11, Associativity::Left },
    
    Marker::LeftShift => { 12, Associativity::Left },
    Marker::RightShift => { 12, Associativity::Left },
    Marker::RightRotate => { 12, Associativity::Left },

    Marker::Plus => { 13, Associativity::Left },
    Marker::Minus => { 13, Associativity::Left },

    Marker::Times => { 14, Associativity::Left },
    Marker::Divide => { 14, Associativity::Left },
    Marker::FloorDivide => { 14, Associativity::Left },

    # 15 for unary -/=/!/~/&

    Marker::Power => { 16, Associativity::Left },

    # 17 for affix ++/--

    # 18 for magic 'maybe'

    # 19 for calls

    # also for indexing
    Marker::Dot => { 20, Associativity::Left }

    # 21 for substitution
}

PrefixOperators = {
    Marker::LowNot => 6,

    Marker::Plus => 15,
    Marker::Minus => 15,
    Marker::Not => 15,
    Marker::BitwiseNot => 15,
    Marker::And => 15,

    Marker::PlusPlus => 17,
    Marker::MinusMinus => 17,

    # Note: precedence isn't actually used since %% wraps the operand
    Marker::Substitution => 21
}

SuffixOperators = {
    Marker::PlusPlus => 17,
    Marker::MinusMinus => 17,

    Marker::Maybe => 18,

    Marker::OpenParen => 19,

    Marker::OpenIndex => 20,
}