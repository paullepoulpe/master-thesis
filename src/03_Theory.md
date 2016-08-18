# Background

## LMS

## Delite

### Motivation

### Design

#### Elems

![Delite Elems Hierarchy](http://www.dotty.ch/g/png?
  digraph G {
    rankdir=BT;
    Def [shape=box,color=gray,style=filled];
    ;
    DeliteLoopElem [shape=box,color= salmon,style=filled];
    ;
    DeliteHashElem [shape=box,color=salmon,style=filled];
    DeliteHashElem -> Def;
    ;
    DeliteHashIndexElem [shape=box,color=salmon,style=filled];
    DeliteHashIndexElem -> DeliteHashElem;
    DeliteHashIndexElem -> DeliteLoopElem;
    ;
    DeliteCollectBaseElem [shape=box,color=salmon,style=filled];
    DeliteCollectBaseElem -> Def;
    DeliteCollectBaseElem -> DeliteLoopElem;
    ;
    DeliteFoldElem [shape=box,color=salmon,style=filled];
    DeliteFoldElem -> DeliteCollectBaseElem;
    ;
    DeliteReduceElem [shape=box,color=salmon,style=filled];
    DeliteReduceElem -> DeliteCollectBaseElem;
    ;
    DeliteCollectElem [shape=box,color=salmon,style=filled];
    DeliteCollectElem -> DeliteCollectBaseElem;
    ;
    DeliteHashReduceElem [shape=box,color=salmon,style=filled];
    DeliteHashReduceElem -> DeliteHashElem;
    DeliteHashReduceElem -> DeliteLoopElem;
    ;
    DeliteHashCollectElem [shape=box,color=salmon,style=filled];
    DeliteHashCollectElem -> DeliteHashElem;
    DeliteHashCollectElem -> DeliteLoopElem;
    ;
    DeliteForeachElem [shape=box,color=salmon,style=filled];
    DeliteForeachElem -> Def;
    DeliteForeachElem -> DeliteLoopElem;
  }
)

