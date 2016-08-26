# Background and Theory

## Domain-specific languages

A domain specific language (DSL), as opposed to a general purpose language, provides a high level of abstraction to the programmer. As the name implies, a DSL is composed of a series of constructs specific to a certain domain. This allows programmers to focus on their domain rather than the underlying implementation of the runtime. Due to their high level of abstraction, DSL's carry an abundance of semantic information. Compilers can take advantage of that information to perform domain-specific optimizations and select the best representation for the executable depending on the specificity of the hardware target [@dsls].

## Multi-stage programming
Multi stage-programming (MSP), or dynamic code generation, is a mechanism that can be used to remove abstraction overhead and efficiently specialize generic programs. MSP splits computations into stages distinguished from one another by frequency of execution or availability of data. This allows evaluating part of the computations early or reducing frequency of execution of other parts. 

Due to its ability to strip abstraction and generate highly efficient code, MSP is especially well suited for performance oriented DSL compilation.

## Parallel patterns

Design patterns are a well understood concept in software engineering [@designpatterns]. They represent a general repeatable solution to a commonly occurring problem. More broadly, they allow programmers to encapsulate semantics about some repeating structured computation. Parallel patterns are no exception, they express structured computations in a parallel setting. Among the best known frameworks for formalizing these patterns are `MapReduce` [@mapreduce] and Spark [@spark].

Delite [@delite] uses the `MultiLoop` (also called Delite `MultiLoop`language, or DMLL) formalism introduced in prior work [@optistructs] [@eatperf]. Each `MultiLoop` is used to define how collections of elements are composed and transformed. There are four operations defined at the core of the `MultiLoop` language. (in the following snippet, type `Coll[V]` is a collection with elements of type `V` and `Int` represents the type of the variable use to index the collection)

```scala
Collect(s)(c)(f)               : Coll[V]
Reduce(s)(c)(f)(r)             : V
BucketCollect(s)(c)(k)(f)      : Coll[Coll[V]]
BucketReduce(s)(c)(k)(f)(r)    : Coll[V]

s: Int                  // range of the loop
c: Int => Boolean       // condition
k: Int => K             // key function
f: Int => V             // value function
r: (V, V) => V          // reduction function
```

`Collect` accumulates all of the values generated and returns them as a collection. The condition function can guard the value function to prevent certain indices from being computed. It can be used to implement `map`, `zipWith` or `filter`. The `Reduce` generator has an additional reduction function that is used to combine the generated values into a single result. It can be used to implement `sum` or `count`.
The `BucketCollect` and `BucketReduce` generators use a key function to reduce and collect values into separate buckets. These operation can be used to implement the semantics of Google's `MapReduce` [@mapreduce].

An example implementation of `Collect` could be the following

```scala
// Collect(s)(c)(f) :
val out = new Coll[V]
for(i <- 0 until s){
    if(c(i)) {
        out += f(i)
    }
}
```
## Optimizations

The DMLL formalism can be used to express a large number of parallel patterns from a small well defined core. This allows for some powerful transformations and optimizations to be expressed in a simple concise way. In this section we present three common optimizations that are part of the Delite compilation pipeline: `ArrayOfStruct` to `StructOfArray`, vertical loop fusion and horizontal loop fusion. These transformations are not new ideas [@soa] [@loopfusion], however, they are essential in the context of Delite. They can remove dependencies between elements of structured data as well as combine computations under the same scope to enable further optimizations.

We will use the following snippet of code to illustrate the different transformations a program goes through.

```scala
case class PersonRecord(name: String, age: Int, height: Double)

val population: Coll[PersonRecord] = Array.fill(100) { i =>
    val name = Disk.getName(i)
    val age = Disk.getAge(i)
    val height = Disk.getHeight(i)
    PersonRecord(name, age, height)
}

val query1 = population.Select(_.height)
val query2 = population.Where(_.age > 40).Select(_.height)
```

This example is a typical example of what a data processing application could look like. We defined some structure data to represent the model we are working with, in this case a record representing a person. We then load a collection of those records from disk storage. Finally, we have two statements that query this collection to compute some result.

The first thing we can notice is that the name field in the `PersonRecord` is never read by the query. In the naive implementation however, these fields have to be loaded from disk, parsed and carried around until they are discarded by the `Select` clause. This creates a computation and memory overhead that might not be negligible, especially if the size of the `name` field is significantly larger than the few bytes required to represent the other two fields.

### `ArrayOfStruct` to `StructofArray`
High level data structures are an essential part of modern programming. Whether designed for functional, imperative or object oriented programming, every language has a mechanism to create complex data structures by grouping simpler ones (`C++`'s `struct`, `Java`'s `class`, `haskell`'s `Product` type). This very useful abstraction can however get in the way of compiler optimizations as it introduces some dependencies between parts of data.

Using a generic implementation of `Records` provided by LMS, Delite is able to understand  how that data is structured. This lets Delite to statically dispatch most field accesses and allows DCE to get rid of the unused fields. 

`ArrayOfStruct` to `StructofArray` (`AoS` to `SoA`) or `MultiLoop` `SoA` is an extension of the mechanism described above that works on collection of `Records`. The transformation iterates over all of the patterns that produce a collection of structures and rewrites them to produce a single structure of collections, each one corresponding to a field in the original structure. It then marks the result to keep track of the transformation and rewrites the original collection's methods to work on the result of the transformation. Using the same mechanism as described above, it can rewrite accesses to the `SoA` representation by statically dispatching them.

Ignoring the second query from the example above, the transformation's result would look something like the following.

The `population` collection can be split into 3 separate collections

```scala
val names: Coll[String] = Array.fill(100){i => Disk.getName(i)}
val ages: Coll[Int] = Array.fill(100){i => Disk.getAge(i)}
val heights: Coll[Double] = Array.fill(100){i => Disk.getHeight(i)}

val population = SoACollection[PersonRecord](
        "name" -> names, 
        "age" -> ages, 
        "height" -> heights)
```

Since the type of the `population` collection is statically known, access to it can be statically dispatched and the query can be rewritten as follows.

```scala
val query1 = heights.Select(x => x)
```
Since the `population` variable is not referenced anywhere in the resulting code, it can be safely eliminated along with the all of the `name` and `age` fields.

### Vertical Loop Fusion

Functional style programming has many advantages. It is easier to reason about independent and composable operations than explicit imperative loops. However, naive implementations of these operations can be very inefficient as they create a large amount of intermediate collections.

Using the second query from our example, we can see that the collection that is being produced by the `Where` clause and consumed by the `Select` is never referenced anywhere else in the code. In these conditions, vertical fusion can merge the body of the producer into the consumer, and thus get rid of the intermediate structure in its entirety. 

It is no accident that we only used the first query in our `SoA` example. The chained operations in the second query prevent us from getting rid of the population, as the intermediate collection depends on the `population` variable.

A simple rule for vertical loop fusion in DMLL might look like the example below (where `fused` is the result of fusion `consumer` and `producer`)

```scala
val producer = Collect(s1)(c1)(f1)
val consumer = Collect(producer.size)(c2)(f2)

val fused = Collect(s1)(c1 && c2)(f1 andThen f2)
```

To visualize the effect of loop fusion on our example above, we first need to give some implementation of `Where` and `Select` using our `MultiLoop` language.

```scala
trait Coll[T] { 
    def size: Int = ... // the size of the colleciton
    def get(idx: Int): T = ... // retrieves the value at idx
    def Where(cond: T => Boolean): Coll[T] = {
        Collect(size)(cond)(i => this.get(i)) 
    }
    def Select(func: T => V): Coll[V] = {
        Collect(size)(_ => true)(i => func.apply(this.get(i)))
    }
}
```

The result of vertical fusion on the second query would thus look like this

```scala
val query2 = Collect(100)(i => ages(i) > 40)(i => heights(i))
```

All of the dependencies to the `SoA` structure have been removed, and the `names` collection can be safely removed from generated code.

### Horizontal Loop Fusion
The problem with the previous two optimizations alone is that now we have a potentially large number of loops that might be duplicating computation. If the elements of the original array shared some code, now this code is duplicated across all of the loops.

The following code for example:

```scala
def genPerson(seed: Int) = ... // expensive computation
val population: Coll[PersonRecord] = Array.fill(100) { i =>
    genPerson(i)
}
```
Would be transformed in quite inefficient by the `SoA` transformer if the `genPerson` function is not inlined:

```scala
val names: Coll[String] = Array.fill(100){i => genPerson(i).name}
val ages: Coll[Int] = Array.fill(100){i => genPerson(i).age}
val heights: Coll[Double] = Array.fill(100){i => genPerson(i).height}
```

To solve this problem we merge all of the loops iterating over the same range. All of the computations will thus be in the same scope and LMS's CSE optimization will take care of sharing the computation for all of the fields.

Applying all of the optimizations described above to our example and lowering the result to our implementation of `Collect`, we obtain the following:

```scala
val query1 = new Coll[Double]
val query2 = new Coll[Double]

for(i <- 0 until 100){
    val height = Disk.getHeight(i)
    query1 += height
    val age = Disk.getAge(i)
    if(age > 40) query2 += height
}
```
All reference to the `names` collection has disappeared. Furthermore, since the collections all iterate over the same range, the fusion algorithm can fuse them together and remove the need to build them in the first place.

Next we will discuss in more details how these optimizations are implemented in the context of the our system. We will show how `MultiLoop`s are encoded in Delite, and how it had to be modified to take advantage of the improvements made in the loop fusion optimizations. We will also present some of the problems we have encountered while redesigning the framework and the tools we have created to help tackle similar problems in the future.

