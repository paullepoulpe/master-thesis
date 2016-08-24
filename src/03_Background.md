# Background and Theory

## Domain-specific languages

A domain specific language (DSL), as opposed to a general purpose language, provides a high level of abstraction to the programmer. As the name implies, a DSL is composed of a series of constructs specific to a certain domain. This allows programmers to focus on their domain rather than the underlying implementation of the runtime. Due to their high level of abstraction, DSL's carry an abundance of semantic information. Compilers can take advantage of that information to perform domain-specific optimizations and select the best representation for the executable depending on the specificity of the hardware target [@dsls].

## Multi-stage programming
Multi stage-programming (MSP), or dynamic code generation, is a mechanism that can be used to remove abstraction overhead and efficiently specialize generic programs. MSP splits computations into stages distiguished from one another by frequency of execution or avalability of data. This allows evaluating part of the computations early or reducing frequency of execution of other parts. 

Due to its ability to strip abstraction and generate highly efficient code, MSP is especially well suited for performance oriented DSL compilation.

## Parallel patterns

Design patterns are a well understood concept in software engineering. They represent a general repeatable solution to a commonly occurring problem. More broadly, they allow programmers to encapsulate semantics about some repeating structured computation. Parallel patterns are no exception, they express structured computations in a parallel setting. Among the best known frameworks for formalizing these patterns are MapReduce [@mapreduce] and Spark [@spark].

Delite [@delite] uses the `MultiLoop` formalism introduced in prior work [@optistructs] [@eatperf]. Each `MultiLoop` is used to define how collections of elements are composed and transformed. There are four operations defined at the core of the `MultiLoop` language. (in the following snippet, type `Coll[V]` is a collection with elements of type `V` and `Index` represents the type of the variable use to index the collection)

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

`Collect` accumulates all of the values generated and returns them as a collection. The condition function can guard the value function to prevent certain indices from being computed. It can be used to implement `map`, `zipWith`, `filter` or `flatmap`. The `Reduce` generator has an additional reduction function that is used to combine the generated values into a single result. It can be used to implement `sum` or `count`.
The `BucketCollect` and `BucketReduce` generators use a key function to reduce and collect values into separate buckets. These operation can be used to implement the semantics of Google's `MapReduce` [@mapreduce].

## Optimizations

The Delite MultiLoop Language (DMLL) formalism can be used to express a large number of parallel patterns from a small well defined core. This allows for some powerful transformations and optimizations to be expressed in a simple concise way. In this section we present three common optimization that are part of the Delite compilation pipeline: `ArrayOfStruct` to `StructOfArray`, vertical loop fusion and horizontal loop fusion. These transformations are not new ideas [@soa] [@loopfusion], however, they are essential in the context of Delite. They can remove dependencies between elements of strucured data as well as combine computations under the same scope to enable further optimizations.

We will use the following example to illustrate the differents transformations a program goes through.

```scala
case class PeopleRecord(name: String, age: Int, 
        height: Double, address: String)

val population: Collection[PeopleRecord] = 
        getFromFile("population.json")

val heights = population.Where(_.age > 40).Select(_.height)
```

As is the case in the example above, most of these queries end up using only part of the information that is available in a given element of the collection. When written functionally, however, and implemented in the naive way, the whole collection has to flow through all the intermediate operations until it is discarded by the final filter. This is unnecessary and causes potentially a lot of memory to be used for no reason. Furthermore if the collection is not local to the computation, the communication overhead can become significant. (TODO: citation needed)

In this section, we present three optimizations that allow us trim the collection of the unused fields as soon as they are not needed. This will make the program use the strictly necessary data.

### `ArrayOfStruct` to `StructofArray`
Using LMS records, Delite can introspect in the structure of the data that composes its collections. This allows us to perform `ArrayOfStruct` to `StructOfArray` or `SoA` transformations.

This transform iterates over all of the loops in the schedule that are generating collections of structures, and replaces them with a collection of loops generating one field of the structure each. It then replaces all references to the original collection with a reference to the corresponding loop.

This allows us to separate the fields from the original collection and remove dependencies between loops that access only one field the structure and the other fields.

*[SR: Maybe you should rewrite the second half of that last sentence...do you mean to say "...remove dependencies between loops that access only one field of the structure and loops [or operations] that access the other fields."]*

TODO: maybe example of result ?

*[SR: Yes I think an example might be nice; either code if it's simple and/or a diagram showing the three transformations...either three separate diagrams or a single diagram showing the three phases, either one would work.]*

### Vertical Loop Fusion
After the `SoA` transformation in the example above, we now have an array for the `address` field that is being created but never actually used. We also generate a `Collection[PeopleRecord]` that is never used for anything else than being consumed by the `Where` clause. Similarly the collection produced by the `Where` clause is immediately consumed by the `Select`.

To avoid creating intermediate collections, Delite uses LMS to perform vertical loop fusion where it merges together the bodies of the consumers in their producers. This results in one large loop that directly computes the `heights` result and allows the scheduler to remove all of the computation needed to compute the `address` field.

TODO: maybe example of result ?

### Horizontal Loop Fusion
The problem with the previous two optimizations alone is that now we have a large number of loops that are potentially duplicating computation. If the elements of the original array shared some code, now this code is duplicated across all of the loops.

To solve this problem we merge all of the loops iterating over the same range. All of the computation will thus be in the same scope and LMS's CSE optimization will take care of sharing the computation for all of the fields.

TODO: maybe example of result ?

*[SR: Background section looks excellent!  You may or may not want a transition paragraph here at the end, preapring the reader for what comes next e.g. something like "Next we will discuss in more detail specifically how we implemented these optimizations in the context of our system, the problems we encountered and the toosl we built to attack those problems blah blah bla... :) ]*
