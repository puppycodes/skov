! Copyright (C) 2015-2016 Nicolas Pénet.
USING: accessors combinators.smart kernel models sequences
skov.code skov.gadgets skov.gadgets.node-gadget ui.gadgets ;
IN: skov.gadgets.node-pile

: <node-pile> ( model -- gadget )
     node-pile new vertical >>orientation { 0 20 } >>gap 1/2 >>align swap >>model ;

M: node-pile model-changed
    dup clear-gadget swap value>>
    [ word/tuple? ]
    [ unconnected-contents>> [ <node-gadget> add-gadget ] each ] smart-when* drop ;
