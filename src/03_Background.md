# Background
<!-- The Delite Compiler Architecture -->
Delite [@delite] is a compiler framework built to enable the development of Domain Specific Languages (DSL). It can then be used to implement high performance applications that compile to various languages (Scala, C++, CUDA) and run on heterogeneous architectures (CPU /GPU). 

## Lightweight Modular Staging // put in implementation for details
Delite uses LMS (or Lightweight Modular Staging [@lms]) to lift user programs written in plain Scala to an intermediate representation that can then be staged to produce more efficient code. It also defines all of the base architecture for analysis and transformation passes.

The IR lms is composed of the following basic blocks:

| Type              | Explanation                                               |
| ----------------- | --------------------------------------------------------- |
| `Exp[+T]`         | Atomic node representing an expression of type T          |
| `Const[+T](x: T)` | Constant expression of type `T` (extends `Exp[T]`)        |
| `Sym[+T](id: Int)`| Symbol of type `T` (extends `Exp[T]`)                     |
| `Def[+T]`         | Composite node that is defined by a library or DSL author |


`Exp[T]` is an interface that represents an expression of type `T`. Constants and symbols are the only elements implementing that interface. Composite operations are defined using `Def`s and can only reference symbols or constants.

During program evaluation, each definition is associated with a symbol, and that symbol is returned in place of the value for use in subsequent operations (see [@virtualization] & [@tagless] for the mechanism through which this is achieved). This allows LMS to perform automatic CSE on the IR as it can lookup if a definition has already been encountered previously and return the same symbol if it is the case.

Each statement is represented as a typed pair (or TP) in LMS. A typed pair is composed of a definition and it's associated symbol. The set of all statements represent the staged program.

The resulting program is generated from the result value, resolving the transitive dependencies and then sorting them topologically to obtain a valid schedule that will produce the result (see [@betterfusion] for a detailed explanation).

Here is a simple snippet of code

```scala
val x1 = x0 + 2
val x2 = x1 > 13
val x4 = if ( x2 ){
  val x3 = x1 * 3
  x3
} else {
  val x1bis = x0 + 2
  x1bis
}
```

And here is the resulting AST

```scala
TP(Sym(1), IntPlus(Sym(0), Const(2)))
TP(Sym(2), OrderingGT(Sym(1), Const(13)))
TP(Sym(3), IntTimes(Sym(1), Const(3)))
TP(Sym(4), IfThenElse(Sym(2), Sym(3), Sym(1)))
```

As we can see, the computation for `x1` has not been duplicated for `x1bis` because it is the same, LMS returned `Sym(1)` in the `IfThenElse` node.

## Transformers and Mirroring
As we've seen in the previous section, LMS can automatically perform generic optimization. For more specific optimizations, LMS provides a transformation API.

A transformer walks through a schedule and processes each statement to decide whether it has to be changed or not. Even when a statement is not modified by the transformer, it's dependencies might have been and that has to be reflected in the node. In LMS, this process is called mirroring.

Since the AST is immutable, mirroring has to generate a new node with the updated dependencies. The mirroring function also has the opportunity to perform domain specific optimization when generating the node depending on changes made to the dependencies.

## The Delite Pipeline

Delite uses LMS to stage DSL programs and generate efficient code. A user program first goes through staging to obtain the AST. It then goes through a series of transformers until it can be fed into a code generator to obtain optimized Scala or C++ code.

The main transformations performed by Delite are :

| Name                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| Device Independent Lowering       | Lowers DSL definitions into generic delite operations such as loop traversals |
| Device Dependent Lowering         | Performs additional transforming specific to the  target platform |
| `Multiloop SoA`                     | Or `ArrayOfStruct` to `StructofArray`. Splits loops generating arrays of structures into multiple loops (one for each field) | 
| Vertical Loop Fusion              | Fuses producer and consumer loops together to eliminate intermediate data structures |
| Horizontal Loop Fusion            | Fuses loops that iterate over the same range into the same loop | 


## Parallel Patterns

### Theory
Delite operations are defined using collection of reusable parallel patterns. They are high level functional procedures that define how `DeliteCollection`s are used and transformed. `DeliteCollection`s are implemented by DSL authors and define the representation of the data. Each operation has very specific semantics and constrains the access pattern on the collection. This allows code generators and analysers to have a precise understanding of the semantics of the program and generate efficient code.

There are four core operations defined in Delite [@eatperf]:
*[SR: table might need just a little more explanation e.g. what is "Coll[V]" etc. in column 2?]*

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

## Optimizations

Data processing application deal with data that is structured in collection of records (`Array`s of `Struct`s). These collections are then queried to compute some information. Here is a toy example:

```scala
case class PeopleRecord(name: String, age: Int, 
        height: Double, address: String)

val population: Collection[PeopleRecord] = 
        fromFile("pop.json").slurp[PeopleRecord]

val heights = population    Where(_.age > 40)  
                            Select(_.values.sum(_.height))
```

As is the case in the example above, most of these queries end up using only part of the information that is available in each element of the collection. When written in a functional way however, if implement in the naive way, the whole collection has to flow through all the intermediate operations until it is discarded by the final filter. This is unnecessary and causes potentially a lot of memory to be used for no reason. Furthermore if the collection is not local to the computation, the communication overhead can become significant. (TODO: citation needed)

In this section, we present three optimizations that allow us trim the collection of the unused fields as soon as they are not needed. This will make the program use the strictly necessary data.

### `ArrayOfStruct` to `StructofArray`
Using lms records, Delite can introspect in the structure of the data that compose its collections. This allows us to perform `ArrayOfStruct` to `StructOfArray` transformations.

This transformer iterates over all of the loops in the schedule that are generating collections of structures and replaces them with a collection of loops generating one field of the structure each. It then replaces all of the references to the original collection with a reference to the corresponding loop.

This allows us to separate the fields from the original collection and remove dependencies between loops that access only one field the structure and the other fields.

TODO: maybe example of result ?

### Vertical Loop Fusion
After `SoA` transformation, in the example above, we now have an array for the `address` field that is being created but never actually used. We also generate a `Collection[PeopleRecord]` that is never used for anything else than being consumed by the `Where` clause. Similarly the collection produced by the `Where` clause is immediately consumed by the `Select`.

To avoid creating intermediate collections, Delite uses lms to perform vertical loop fusion where it merges together the bodies of the consumers in their producers. This results in one large loops that directly computes the `heights` result and allows the scheduler to remove all of the computation needed to compute the `address` field.

TODO: maybe example of result ?

### Horizontal Loop Fusion
The problem with the previous two optimizations alone is that now we have a large number of loops that are potentially duplicating computation. If the elements of the original array shared some code, now this code is duplicate across all of the loops.

To solve this problem we merge all of the loops iterating over the same range. All of the computation will thus be in the same scope and LMS's CSE optimization will take car of sharing the computation for all of the fields.

TODO: maybe example of result ?
