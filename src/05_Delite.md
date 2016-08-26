# The Delite Compiler Architecture
Delite [@delite] is a compiler framework built to enable the development of Domain Specific Languages (DSL). The DSL can then be used to implement high performance applications that compile to various languages (Scala, C++, CUDA) running
on heterogeneous architectures (CPU /GPU). 

Delite is composed of two separate parts, a compilation framework, and a runtime environment. We refer exclusively to the framework part in this report when we use the term `Delite`. The implementation of the runtime does not affect our discussion here.

## Compilation Pipeline

Delite uses LMS's staging mechanism to lift DSL programs into IR. This IR then goes through a series of transformers and optimizations before code generation.

The main transformations phases performed by Delite are:

| Name                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| Device Independent Lowering       | Lowers DSL definitions into generic Delite operations such as loop traversals |
| Device Dependent Lowering         | Performs additional transforms specific to the  target platform |
| `Multiloop SoA`                     | Or `ArrayOfStruct` to `StructofArray`. Splits loops generating arrays of structures into a single structure of multiple loops generating an array for each field. | 
| Vertical Loop Fusion              | Fuses producer and consumer loops to eliminate intermediate data structures |
| Horizontal Loop Fusion            | Fuses loops that iterate over the same range | 


## Delite Ops

To simplify the development of DSL's, Delite provides a large collection of reusable operations (ops). Those operations include, among other things, the Delite `MultiLoop` Language (DMLL) we presented in a previous section. This allows new ops to be created that use the core DMLL generators and are thus automatically supported by the compilation pipeline.

### Elems
To encode their ops, Delite defines a set of basic IR nodes (`DeliteOpsIR`) called `Elems` that define the semantics of the different operations and can be used as loop bodies. DMLL's generators are also encoded as `Elems`.

In the type hierarchy of Delite's `Elems` below, we can easily recognize our four DMLL generators [^1]. 

[^1]: `BucketCollect` (resp. `BucketReduce`) is named `HashCollect` (resp. `HashReduce`) in the Delite context.

![Delite Elems Hierarchy](https://www.dotty.ch/g/png?
  digraph G {
    rankdir=BT;
    node[shape=box,style=filled];
    Def [color=gray];
    ;
    DeliteLoopElem [color= salmon];
    ;
    DeliteHashElem [color=salmon];
    DeliteHashElem -> Def;
    ;
    DeliteHashIndexElem [color=salmon];
    DeliteHashIndexElem -> DeliteHashElem;
    DeliteHashIndexElem -> DeliteLoopElem;
    ;
    DeliteCollectBaseElem [color=salmon];
    DeliteCollectBaseElem -> Def;
    DeliteCollectBaseElem -> DeliteLoopElem;
    ;
    DeliteFoldElem [color=salmon];
    DeliteFoldElem -> DeliteCollectBaseElem;
    ;
    DeliteReduceElem [color=salmon];
    DeliteReduceElem -> DeliteCollectBaseElem;
    ;
    DeliteCollectElem [color=salmon];
    DeliteCollectElem -> DeliteCollectBaseElem;
    ;
    DeliteHashReduceElem [color=salmon];
    DeliteHashReduceElem -> DeliteHashElem;
    DeliteHashReduceElem -> DeliteLoopElem;
    ;
    DeliteHashCollectElem [color=salmon];
    DeliteHashCollectElem -> DeliteHashElem;
    DeliteHashCollectElem -> DeliteLoopElem;
    ;
    DeliteForeachElem [color=salmon];
    DeliteForeachElem -> Def;
    DeliteForeachElem -> DeliteLoopElem;
  }
)




### Ops
Delite `Ops` compose the interface that's facing DSL authors. They provide the building blocks for defining operations on DSL defined data structures. 

Delite Loops, for example, extend the simple loop mechanism provided by LMS, and provide operations to compose or transform `DeliteCollection`s.

```scala
abstract class AbstractLoop[A] extends Def[A] {
  val size: Exp[Int]
  val v: Sym[Int]
  val body: Def[A]
}

sealed trait DeliteOp[A] extends Def[A] {
  type OpType <: DeliteOp[A]
}

/** The base class for most data parallel Delite ops. */
abstract class DeliteOpLoop[A] extends AbstractLoop[A] 
        with DeliteOp[A] {
  type OpType <: DeliteOpLoop[A]
  val numDynamicChunks:Int = 0
}
```

`DeliteCollection` is an interface provided by Delite for DSL authors. These latter can implement it with their own collection and use Delite Ops to operate on them, as in the diagram below.

![Delite loops hierarchy](http://www.dotty.ch/g/png?
  digraph G {
    rankdir=BT;
    node[shape=box,style=filled];
    Def [color=gray];
    ;
    AbstractLoop [color=gray];
    AbstractLoop -> Def;
    ;
    DeliteOp [color=salmon];
    DeliteOp -> Def;
    ;
    DeliteOpLoop [color=salmon];
    DeliteOpLoop -> AbstractLoop;
    DeliteOpLoop -> DeliteOp;
    ;
    DeliteOpCollectLoop [color=lightblue];
    DeliteOpCollectLoop -> DeliteOpLoop;
    ;
    DeliteOpFlatMapLike [color=lightblue];
    DeliteOpFlatMapLike -> DeliteOpCollectLoop;
    ;
    DeliteOpFoldLike [color=lightblue];
    DeliteOpFoldLike-> DeliteOpCollectLoop;
    ;
    DeliteOpReduceLike [color=lightblue];
    DeliteOpReduceLike -> DeliteOpCollectLoop;
    ;
    DeliteOpForeach [color=lightblue]; 
    DeliteOpForeach -> DeliteOpLoop
    ;
    DeliteOpHashCollectLike [color=lightblue];
    DeliteOpHashCollectLike -> DeliteOpLoop;
    ;  
    DeliteOpHashReduceLike [color=lightblue];
    DeliteOpHashReduceLike -> DeliteOpLoop;
    ;
    DeliteOpMapLike [color=lightblue];
    DeliteOpMapLike -> DeliteOpFlatMapLike;
    ;
    DeliteOpMapI [color=lightblue];
    DeliteOpMapI -> DeliteOpMapLike;
    ;
    DeliteOpFilterI [color=lightblue];
    DeliteOpFilterI -> DeliteOpFlatMapLike;
    ;
    DeliteOpFlatMapI [color=lightblue];
    DeliteOpFlatMapI -> DeliteOpFlatMapLike;
  }
)
