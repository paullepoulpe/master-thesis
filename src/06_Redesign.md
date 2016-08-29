# Redesigning Delite Ops
In her new implementation of loop fusion[@betterfusion], Vera Salvisberg proposes a new `flatMap`-based IR for loop operations. Since `map` and `filter` can be expressed as specific cases of `flatMap`, this model is general enough to capture the semantics of most collection operations. In this section, we show how we update Delite's encoding of loops to support those changes. We also update code generators and the `SoA` transformation to support the new model. Other changes in Delite are not discussed.

## Before
As we saw in the previous section, the generators from DMLL are represented as `Elem`s in Delite. We now present how these `Elem`s are implemented. We also show the limitations of DMLL and how the improvements in loop fusion help us get rid of these limitations.

```scala
// Base trait for all loop elems in Delite
trait DeliteLoopElem {
    val numDynamicChunks:Int
}

// Collect generator
case class DeliteCollectElem[A, CA <: DeliteCollection[A]]] 
        extends Def[CA] with DeliteLoopElem {
    type I <: DeliteCollection[A]

    // Collect generator parameters
    val func: Block[A]
    val cond: List[Block[Boolean]] = Nil
    
    // The output collection
    val par: DeliteParallelStrategy
    val buf: DeliteBufferElem[A,I,CA]
    
    // Support for flatmap operations
    val iFunc: Option[Block[DeliteCollection[A]]] = None
    
    // symbol to iterate over the intermediate 
    // collection during flatMap operations
    val iF: Option[Sym[Int]] = None
    
    // size of the intermediate collection
    // for flatmap operations
    val sF: Option[Block[Int]] = None
    
    // symbol to hold the intermediate collection
    // during flatmap operations
    val eF: Option[Sym[DeliteCollection[A]]] = None
}
```
The first thing we notice with this implementation is that even though it supports `flatMap` operations, the encoding is quite strange. The `MultiLoop` language[@eatperf] does not actually have enough expressive power to encode `flatMap` operations. Here this support is added through the `iFunc` field and is set only for that specific case.

The second problem with the above encoding is less obvious. The following example from Vera illustrate it well:

```scala
val prod = Collect(10)(i => i != 2)(i => i - 2)val cons = prod.Fold(prod.size)
                (_ => true)
                (i => prod(i))
                (zero = 0.0, reduce = { (x,y) => x + 1.0/y })
```

The `Fold` operation above is similar to our `Reduce` generator. It defines an additional `zero` element that is used as an initial value for the result accumulator. We call `prod` the producer and `cons` the consumer because the `Fold` operation uses the collection produced by the `Collect` as input. The lowered consumer looks as follows:
```scalaSimpleLoop(prod.length, indexVar,    DeliteFoldElem(0, cons, elemVal,        { indexVar => prod.at(indexVar) }, // the map function        { indexVar => cons + 1.0/elemVal }, // the reduce function        Nil // no conditions yet    )
)
```
After vertical fusion:

```scalaSimpleLoop(10, indexVar,    DeliteFoldElem(0, cons, elemVal,        { indexVar => indexVar - 2 }, // fused map      
        { indexVar => cons + 1.0/elemVal },         List(indexVar != 2) // added condition
    )
)
```

The problem appears when we try to generate the code:
```scala
var cons = 0for (indexVar <- 0 until 10) {    val elemVal = indexVar - 2    val res = cons + 1.0/elemVal    val condition = (indexVar != 2)    if (condition) cons = res}
```

Even though the original code did contain any error, the generated code will cause an arithmetic exception as it tries to divide by zero. We can try to fix this problem by always emitting the code for the condition first, and computing the value function conditionally. This might generate some erroneous code however in the cases where the consumer contains a conditional. In the example below, the `print` statement is executed twice as often as it should [^1redesign]:

```scala
val prod = Collect(10)(_ => true)(i => {print(i); i + 1})
val cons = Collect(prod.size)(_ % 2 == 0)(i => prod(i))
```

After loop fusion and lowering:

```scala
var cons = []
for (indexVar <- 0 until 10) {
    print(indexVar)
    val condition = (indexVar + 1)  % 2 == 0
    if (condition) {
        print(indexVar)
        val res = (indexVar + 1) 
        cons += res
    }
}
```

The fundamental problem with this encoding is that the condition and value function of our generator are stored in different blocks within the `Elem`. This causes them to be emitted separately by code generation. The scheduler can therefore not see the dependencies between both blocks and duplicates part of the computation.

## After
The mechanism used by fusion to match the shape of a loop body is called an extractor. The terminology used for extractors is similar to the one for DMLL generators. For example a `Collect` extractor matches on loop bodies that produce a single element for each iteration. The new version of fusion introduces the concept of a `MultiCollect` extractor. This extractor matches on all loop bodies that produce a collection of elements for each iteration (like `flatMap`). It also introduces two specialized extractors: `Singleton` and `Empty` to match on bodies of `filter`-like and `map`-like operations. 

This allows us to change the encoding of our `CollectElem`s by expressing them in terms of `flatMap`-like operations. We update the Delite `MultiLoop` language to reflect this change:

```scala
MultiCollect(s)(iF)          : Coll[V]
Reduce(s)(iF)(r)             : V
BucketCollect(s)(k)(iF)      : Coll[Coll[V]]
BucketReduce(s)(k)(iF)(r)    : Coll[V]

s: Int                  // range of the loop
k: Int => K             // key function
iF: Int => Coll[V]      // value function
r: (V, V) => V          // reduction function
```

With this new set of generators, we can encode `flatMap` operations as well as the previous `Collect` generator:

```scala
Collect(s)(c)(f) = MultiCollect(s)(if(c){Singleton(f)}else{Empty})
```

where `Empty` represents the empty collection and `Singleton` is a collection of size one. This means that the new version of DMLL is strictly more expressive than our original definition. The need for an additional condition field is also removed. 

Our updated implementation now encodes the information about the condition and value function in the same block. The scheduler is therefore aware of all the dependencies within the body of the loop and can properly guard the value function while not duplicating computation:

```scala
trait DeliteLoopElem[A] extends Def[A] {
    val numDynamicChunks:Int
}

abstract class DeliteCollectBaseElem[A, O] 
        extends DeliteLoopElem[O] {
          
    val iFunc: Block[DeliteCollection[A]]
    val unknownOutputSize: Boolean

    // symbol to hold the intermediate collection
    val eF: Sym[DeliteCollection[A]]

    // symbol to iterate over the intermediate collection
    val iF: Sym[Int]
    
    // size of the intermediate collection
    val sF: Block[Int]
    
    // element of the intermediate collection at 
    // the current inner loop index
    val aF: Block[A]
}

case class DeliteCollectElem[A, CA <: DeliteCollection[A]] 
        extends DeliteCollectBaseElem[A, CA] {

    type I <: DeliteCollection[A]
    
    // The output collection/buffer to be used
    val buf: DeliteCollectOutput[A,I,CA]
}
```

In the case of a `map` or `filter` operation, we do not actually need to allocate any intermediate collection. In order to avoid the extra allocations, we need to add some logic to the code generation phase to handle the special `MultiCollect` operations. Similar to loop fusion's extractors, we create a set of classes that allows us to match the shapes of our loop bodies:[^2redesign].


```scala
abstract class DeliteCollectType

case class CollectMap(elem: Block[Any]) extends DeliteCollectType
        
case class CollectFilter(cond: Exp[Boolean], thenElem: Block[Any]) 
    extends DeliteCollectType

case object CollectFlatMap extends DeliteCollectType
```

We then define an extractor function that the code generator can use to specialize code depending on the shape of the loop:

```scala
def getCollectElemType(collect: DeliteCollectBaseElem[_,_])
        : DeliteCollectType = collect.iFunc match {
    case Singleton(siElem : Block[Any]) =>
        CollectMap(siElem)
    
    case Conditional(cond, Singleton(thenElem), Empty) =>
        CollectFilter(cond, thenElem)
  
    case _ => CollectFlatMap
}
```

To support the `SoA` transformation on our new loop bodies, we use our extractor to discriminate between the different kind of `MultiCollect` generators. This allows us to limit the changes needed in the code of the transformer. We make changes in two places only. We add logic to the entry point of the transformer to extract the condition and value function parameters from our loop bodies. We also save the type of extractor that was used. We then update the function responsible for generating a loop for each field such that it builds a new `iFunc` field from the updated parameters while respecting the shape of the saved extractor.

[^1redesign]: Scala has had a similar issue itself https://groups.google.com/forum/#!msg/scala-internals/sbvCLxPyDcA/6dr40vqUS40J 
[^2redesign]: For the sake of simplicity, we ignore the handling of effects here.