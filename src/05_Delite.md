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

To simplify the development of DSLs, Delite provides a large collection of reusable operations (ops). Those operations include, among other things, the Delite `MultiLoop` Language (DMLL) we presented in a previous section. This allows new ops to be created that use the core DMLL generators and are thus automatically supported by the compilation pipeline.

### `DeliteLoopElem`s
To encode their ops, Delite defines a set of basic IR nodes (`DeliteOpsIR`) called `Elems` that are used as loop bodies. An `Elem` defines the semantics of the loop. It encodes the output type of the loop: `DeliteCollectElem` will produce a collection of values, whereas `DeliteReduceElem` will produce a single value. It also contrains the kind of operations allowed inside the loop: an instance of `DeliteForeachElem` can cause arbitrary side effects whereas the effects caused by a `DeliteReduceElem` are limited to modifying its accumulator. 

All of the DMLL generators are encoded using `Elems`. Other kind of operations are supported too. However, the support for fusion is limited for those operations. We can easily recognize our four DMLL generators in the inheritence hierarchy below[^1delite].

![Delite `Elem`s Hierarchy](https://www.dotty.ch/g/png?
  digraph G {
    rankdir=BT;
    node[shape=box,style=filled];
    Def [color=gray];
    ;
    LoopElem [color= salmon];
    ;
    HashElem [color=salmon];
    HashElem -> Def;
    ;
    HashIndexElem [color=salmon];
    HashIndexElem -> HashElem;
    HashIndexElem -> LoopElem;
    ;
    CollectBaseElem [color=salmon];
    CollectBaseElem -> Def;
    CollectBaseElem -> LoopElem;
    ;
    FoldElem [color=salmon];
    FoldElem -> CollectBaseElem;
    ;
    ReduceElem [color=salmon];
    ReduceElem -> CollectBaseElem;
    ;
    CollectElem [color=salmon];
    CollectElem -> CollectBaseElem;
    ;
    HashReduceElem [color=salmon];
    HashReduceElem -> HashElem;
    HashReduceElem -> LoopElem;
    ;
    HashCollectElem [color=salmon];
    HashCollectElem -> HashElem;
    HashCollectElem -> LoopElem;
    ;
    ForeachElem [color=salmon];
    ForeachElem -> Def;
    ForeachElem -> LoopElem;
  }
)




### `DeliteOp`s
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
    ;
    DeliteOpLoop [color=salmon];
    ;
    CollectLoop [color=lightblue];
    CollectLoop -> DeliteOpLoop;
    ;
    FlatMapLike [color=lightblue];
    FlatMapLike -> CollectLoop;
    ;
    FoldLike [color=lightblue];
    FoldLike-> CollectLoop;
    ;
    ReduceLike [color=lightblue];
    ReduceLike -> CollectLoop;
    ;
    Foreach [color=lightblue]; 
    Foreach -> DeliteOpLoop
    ;
    HashCollectLike [color=lightblue];
    HashCollectLike -> DeliteOpLoop;
    ;  
    HashReduceLike [color=lightblue];
    HashReduceLike -> DeliteOpLoop;
    ;
    MapLike [color=lightblue];
    MapLike -> FlatMapLike;
    ;
    MapI [color=lightblue];
    MapI -> MapLike;
    ;
    FilterI [color=lightblue];
    FilterI -> FlatMapLike;
    ;
    FlatMapI [color=lightblue];
    FlatMapI -> FlatMapLike;
  }
)

[^1delite]: `BucketCollect` (resp. `BucketReduce`) is named `HashCollect` (resp. `HashReduce`) in the Delite context.