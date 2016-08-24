# The Delite Compiler Architecture
Delite [@delite] is a compiler framework built to enable the development of Domain Specific Languages (DSL). It can then be used to implement high performance applications that compile to various languages (Scala, C++, CUDA) and run on heterogeneous architectures (CPU /GPU). 

Delite is composed of two separate parts

## Compilation Pipeline

Delite uses LMS to stage DSL programs and generate efficient code. A user program first goes through staging to obtain the AST. It then goes through a series of transformers until it can be fed into a code generator to obtain optimized Scala or C++ code.

The main transformations performed by Delite are :

| Name                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| Device Independent Lowering       | Lowers DSL definitions into generic delite operations such as loop traversals |
| Device Dependent Lowering         | Performs additional transforming specific to the  target platform |
| `Multiloop SoA`                     | Or `ArrayOfStruct` to `StructofArray`. Splits loops generating arrays of structures into multiple loops (one for each field) | 
| Vertical Loop Fusion              | Fuses producer and consumer loops together to eliminate intermediate data structures |
| Horizontal Loop Fusion            | Fuses loops that iterate over the same range into the same loop | 


<!-- The Delite Compiler Architecture -->


## Parallel Patterns

### Implementation

Delite uses 
*[or, "Delite is designed using"]* 
parallel loops that process `DeliteCollection`s. Each loop has a size and a loop index as well as a loop body. The loop size may refer to another collection, and the loop body is an arbitrary definition representing the result of the loop computation.

```scala
abstract class AbstractLoop[A] extends Def[A] with CanBeFused {
  val size: Exp[Int]
  val v: Sym[Int]
  val body: Def[A]
}

sealed trait DeliteOp[A] extends Def[A] {
  type OpType <: DeliteOp[A]
}

/** The base class for most data parallel Delite ops. */
abstract class DeliteOpLoop[A] extends AbstractLoop[A] with DeliteOp[A] {
  type OpType <: DeliteOpLoop[A]
  val numDynamicChunks:Int = 0
}
```

Most of the `DeliteOp`s are loops, and define a `DeliteElem` as their body. A DSL author uses exclusively `DeliteOp`s to define operations. The Delite architecture then uses the corresponding `Elem`s to perform transformations.


![Delite Elems Hierarchy](https://www.dotty.ch/g/png?
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

![Delite Loops hierarchy](http://www.dotty.ch/g/png?
  digraph G {
    rankdir=BT;
    Def [shape=box,color=gray,style=filled];
    ;
    AbstractLoop [shape=box,color=gray,style=filled];
    AbstractLoop -> Def;
    ;
    DeliteOp [shape=box,color=salmon,style=filled];
    DeliteOp -> Def;
    ;
    DeliteOpLoop [shape=box,color=salmon,style=filled];
    DeliteOpLoop -> AbstractLoop;
    DeliteOpLoop -> DeliteOp;
    ;
    DeliteOpCollectLoop [shape=box,color=lightblue,style=filled];
    DeliteOpCollectLoop -> DeliteOpLoop;
    ;
    DeliteOpFlatMapLike [shape=box,color=lightblue,style=filled];
    DeliteOpFlatMapLike -> DeliteOpCollectLoop;
    ;
    DeliteOpFoldLike [shape=box,color=lightblue,style=filled];
    DeliteOpFoldLike-> DeliteOpCollectLoop;
    ;
    DeliteOpReduceLike [shape=box,color=lightblue,style=filled];
    DeliteOpReduceLike -> DeliteOpCollectLoop;
    ;
    DeliteOpForeach [shape=box,color=lightblue,style=filled]; 
    DeliteOpForeach -> DeliteOpLoop
    ;
    DeliteOpHashCollectLike [shape=box,color=lightblue,style=filled];
    DeliteOpHashCollectLike -> DeliteOpLoop;
    ;  
    DeliteOpHashReduceLike [shape=box,color=lightblue,style=filled];
    DeliteOpHashReduceLike -> DeliteOpLoop;
    ;
    DeliteOpMapLike [shape=box,color=lightblue,style=filled];
    DeliteOpMapLike -> DeliteOpFlatMapLike;
    ;
    DeliteOpMapI [shape=box,color=lightblue,style=filled];
    DeliteOpMapI -> DeliteOpMapLike;
    ;
    DeliteOpFilterI [shape=box,color=lightblue,style=filled];
    DeliteOpFilterI -> DeliteOpFlatMapLike;
    ;
    DeliteOpFlatMapI [shape=box,color=lightblue,style=filled];
    DeliteOpFlatMapI -> DeliteOpFlatMapLike;
  }
)
