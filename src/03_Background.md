# The Delite Compiler Architecture
Delite [@delite] is a compiler framework built to enable the development of Domain Specific Languages (DSL). It can the be used to implement high performance applications that compile to various languages (Scala, C++, CUDA) and run on heterogeneous architectures (CPU /GPU). 

## Lightweight Modular Staging
Delite uses LMS (or Lightweight Modular Staging [@lms]) to lift user programs written in plain scala to an intermediate representation that can then be staged to produce more efficient code. It also defines all of the base architecture for analysis and transformation passes.

The IR lms is composed of the following basic blocks:

| Type              | Explanation                                               |
| ----------------- | --------------------------------------------------------- |
| `Exp[+T]`         | Atomic node representing an expression of type T          |
| `Const[+T](x: T)` | Constant expression of type `T` (extends `Exp[T]`)        |
| `Sym[+T](id: Int)`| Symbol of type `T` (extends `Exp[T]`)                     |
| `Def[+T]`         | Composite node that is defined by a library or dsl author |


`Exp[T]` is an interface that represents an expression of type `T`. Constants and symbols are the only elements implementing that interface. Composite operations are defined using `Def`s and can only reference symbols or constants.

During program evaluation, each definition is associated with a symbol, and that symbol is returned in place of the value for use in subsequent operations (see [@virtualization] & [@tagless] for the mechanism through which this is achieved). This allows LMS to perform automatic CSE on the IR as it can lookup if a definition has already been encountered previously and return the same symbol if it is the case.

Each definition with it's symbol are represented as a typed pair (or TP) in LMS. The set of all the typed pairs represent the staged program.

The resulting program is the generated from the result value, resolving the transitive dependencies and then sorting them topologically to obtain a valid schedule than will produce the result (see [@betterfusion] for a detailed explanation).

## Parallel Patterns

### Theory
Delite operations are defined using collection of reusable parallel patterns. They are high level functional procedures that define how `DeliteCollection`s are used and transformed. `DeliteCollection`s are implemented by DSL authors and define the representation of the data. Each operation has very specific semantics and constraints the access pattern on the collection. This allows code generators and analysis to have a precise understanding of the semantics of the program and generate efficient code.

There are 4 core operations defined in Delite [@eatperf]:

```scala
Collect(c)(f)               : Coll[V]
Reduce(c)(f)(r)             : V
BucketCollect(c)(k)(f)      : Coll[Coll[V]]
BucketReduce(c)(k)(f)(r)    : Coll[V]

c: Index => Boolean     // condition
k: Index => K           // key function
f: Index => V           // value function
r: (V, V) => V          // reduction function
```

These patterns are then extended to implement more specific operations. For example `Collect` can be used to implement `Map` or `Filter`, and `Reduce` can be extended to `Fold` or `Sum`.

Delite provides code generators from each of these patterns to multiple platforms.

### Implementation

The way delite is designed is using parallel loops that process `DeliteCollection`s. Each loop has a size, a loop index as well as a loop body. The loop size may refer to another collection. and the loop body is an arbitrary definition representing the result of the loop computation.

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


