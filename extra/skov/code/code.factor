! Copyright (C) 2015 Nicolas Pénet.
USING: accessors arrays combinators combinators.smart effects
fry hashtables.private kernel listener locals math.parser
sequences splitting vectors vocabs.parser ;
FROM: namespaces => change-global ;
IN: skov.code

TUPLE: element  name parent contents path ;
TUPLE: vocab < element ;
TUPLE: word < element  defined? result ;
TUPLE: connector < element  link ;
TUPLE: input < connector ;
TUPLE: output < connector  id ;
TUPLE: text < element ;
TUPLE: tuple-class < element ;
TUPLE: slot < element  initial-value ;
TUPLE: constructor < word ;
TUPLE: destructor < word ;
TUPLE: accessor < word ;
TUPLE: mutator < word ;

TUPLE: special-input < input ;
TUPLE: special-output < output ;
UNION: special-connector  special-input special-output ;

GENERIC: outputs>> ( obj -- seq )
GENERIC: tuples>> ( obj -- seq )
GENERIC: slots>> ( obj -- seq )
GENERIC: connectors>> ( obj -- seq )
M: element vocabs>> ( elt -- seq ) contents>> [ vocab? ] filter ;
M: element words>> ( elt -- seq ) contents>> [ word? ] filter ;
M: element connectors>> ( elt -- seq ) contents>> [ connector? ] filter ;
M: element inputs>> ( elt -- seq ) contents>> [ input? ] filter ;
M: element outputs>> ( elt -- seq ) contents>> [ output? ] filter ;
M: element tuples>> ( elt -- seq ) contents>> [ tuple-class? ] filter ;
M: element slots>> ( elt -- seq ) contents>> [ slot? ] filter ;

:: add-element ( parent child-class -- parent )
     child-class new parent >>parent parent [ ?push ] change-contents ;

:: add-with-name ( parent child-name child-class -- parent )
     child-class new child-name >>name parent >>parent parent [ ?push ] change-contents ;

: remove-from-parent ( child -- )
     dup parent>> contents>> remove-eq! drop ;

:: change-name ( str pair -- str )
    str pair first = [ pair second ] [ str ] if ;

GENERIC: factor-name ( obj -- str )

M: element factor-name
    name>> " " "-" replace ;

M: word factor-name
    name>> { 
      { "lazy filter" "lfilter" }
      { "while" "special-while" }
      { "until" "special-until" }
    }
    [ change-name ] each
    dup [ CHAR: { swap member? not ] [ CHAR: " swap member? not ] bi and
    [ " " "-" replace ] when ;

M: constructor factor-name
    name>> " " "-" replace "<" ">" surround ;

M: destructor factor-name
    name>> " " "-" replace ">" "<" surround ;

M: accessor factor-name
    name>> " " "-" replace ">>" append ;

M: mutator factor-name
    name>> " " "-" replace ">>" swap append ;

M: text factor-name
    name>> "\"" "\"" surround ;

: replace-quot ( seq -- seq )
    [ dup array? [ first "quotation" " " glue ] [ ] if ] map ;

: convert-stack-effect ( stack-effect -- seq seq )
    [ in>> replace-quot ] [ out>> replace-quot ]
    [ out-var>> dup dup "." = not and [ suffix ] [ drop ] if ] tri ;

: add-to-interactive-vocabs ( vocab-name -- )
    '[ _ suffix ] interactive-vocabs swap change-global ;

: same-name-as-parent? ( word -- ? )
    dup parent>> [ name>> ] bi@ = ;

: input-output-names ( word -- seq seq )
    [ inputs>> ] [ outputs>> ] bi [ [ name>> ] map ] bi@ ;

:: in-out ( word -- seq seq )
    word factor-name :> name
    [ { { [ word same-name-as-parent? ] [ word parent>> input-output-names ] }
        { [ name CHAR: { swap member? ] [ { } { "sequence" } ] }
        { [ name string>number ] [ { } { "number" } ] }
        { [ name search not ] [ { } { } ] }
        [ name search dup vocabulary>> word path<< stack-effect convert-stack-effect ]
      } cond ] with-interactive-vocabs ;

: add-special-connectors ( node -- node )
    [ inputs>> empty? ] [ special-input add-element ] smart-when
    [ outputs>> empty? ] [ special-output add-element ] smart-when ;

GENERIC: add-connectors ( node -- node )
M: input add-connectors  f >>contents dup name>> output add-with-name ;
M: output add-connectors  f >>contents dup name>> input add-with-name ;
M: text add-connectors  f >>contents dup name>> output add-with-name ;
M: slot add-connectors  f >>contents ;

M: word add-connectors
    f >>contents dup in-out
    [ [ input add-with-name ] each ]
    [ [ output add-with-name ] each ] bi*
    add-special-connectors ;

: order-connectors ( connector connector -- connector connector )
    dup output? [ swap ] when ;

: output-and-input? ( connector connector -- ? )
    [ output? ] [ input? ] bi* and ;

: same-word? ( connector connector -- ? )
    [ parent>> ] bi@ eq? ;

GENERIC: connected? ( connector -- ? )

M: element connected?
    connectors>> [ connected? ] any? ;

M: connector connected?
    [ contents>> empty? ] [ link>> connector? ] [ call-next-method ] smart-if ;

GENERIC: connect ( connector1 connector2 -- )

M: connector connect
    2dup link<< swap link<< ;

: disconnect ( connector -- )
    dup link>> [ f >>link drop ] bi@ ;

: ?connect ( connector connector -- )
    [ [ connector? ] bi@ and ]
    [ order-connectors 
      [ [ output-and-input? ] [ nip connected? not ] [ same-word? not ] 2tri and and ]
      [ connect ] smart-when* 
    ] smart-when* ;

: complete-graph? ( word -- ? )
    contents>> [ connected? ] reject empty? ;

: executable? ( word -- ? )
   { [ complete-graph? ] [ inputs>> empty? ] [ outputs>> empty? ]
     [ words>> empty? not ] [ defined?>> ] } cleave and and and and ;

: error? ( word -- ? )
   { [ name>> empty? not ] [ complete-graph? not ]
     [ complete-graph? ] [ defined?>> not ] } cleave and or and ;

CONSTANT: variadic-words { "add" "mul" "and" "or" "min" "max" }

: variadic? ( word -- ? )
    name>> variadic-words member? ;
