# The Delite Compiler Architecture
Delite [@delite] is a compiler framework built to enable the development of Domain Specific Languages (DSL). It can then be used to implement high performance applications that compile to various languages (Scala, C++, CUDA) and run on heterogeneous architectures (CPU /GPU). 

Delite is composed of two separate parts, a compilation framework, and a runtime environment. We refer exclusively to the framework part in this report when we use the term `Delite`. The implementation of the runtime does not affect our discussion here.

## Compilation Pipeline

Delite uses LMS's staging mechanism to lift DSL programs into IR. This IR then goes through a series of transformers and optimization before it reaches code generation.

The main transformations phases performed by Delite are the following:

| Name                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| Device Independent Lowering       | Lowers DSL definitions into generic delite operations such as loop traversals |
| Device Dependent Lowering         | Performs additional transforming specific to the  target platform |
| `Multiloop SoA`                     | Or `ArrayOfStruct` to `StructofArray`. Splits loops generating arrays of structures into a single strucutre multiple loops generating an array for each field. | 
| Vertical Loop Fusion              | Fuses producer and consumer loops together to eliminate intermediate data structures |
| Horizontal Loop Fusion            | Fuses loops that iterate over the same range into the same loop | 


## Delite Ops

To simplify the developpment of DSL's, Delite provides a large collection of reusable operations (ops). Those operations include, among other things, the Delite `MultiLoop` Language (DMLL) we presented in a previous section. This allows new ops to be created that use the core DMLL generators and are thus automatically supported by the compilation pipeline.

### Elems
In their encoding of their ops, Delite defines a set of basic IR nodes (`DeliteOpsIR`) called `Elems` that define the semantics of the different operations and can be used as loops body. DMLL's generators are also encoded as `Elems`.

Here is the type hierarchy of Delite's `Elems`

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

We can easily recognize our four DMLL generators [^1].

[^1]: `BucketCollect` (resp. `BucketReduce`) is named `HashCollect` (resp. `HashReduce`) in the Delite context

### Ops
Delite `Ops` compose the interface that's facing DSL authors. They provide the building blocks for defining operations on DSL defined data structures. 

Delite Loops, for example, extend the simple loop mechanism provided by LMS, and provide operations to composer or transform `DeliteCollection`s.

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

`DeliteCollection` is an interface provided by Delite for DSL authors. These latter can implement it with their own collection and use Delite Ops to operate on them.

![Delite loops hierarchy](http://www.dotty.ch/g/png?
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
