# Redesigning Delite Ops

As we saw in the previous section, the generators from DMLL are represented as `elem`s in Delite. We now present how these `elem`s are implemented. We also show the limitations of DMLL and how the improvements in loop fusion help us get rid of these limitations.

In the following code, we see the encoding that Delite has used until now.

```scala
// Base trait for all loop elems in Delite
trait DeliteLoopElem {
    val numDynamicChunks:Int
}

// Collect generator, 
case class DeliteCollectElem[A, CA <: DeliteCollection[A]]] 
        extends Def[CA] with DeliteLoopElem {
    type I <: DeliteCollection[A]

    // Collect generator parameters
    val func: Block[A]
    val cond: List[Block[Boolean]] = Nil
    
    // the output collection
    val par: DeliteParallelStrategy
    val buf: DeliteBufferElem[A,I,CA]
    
    // Support for flatmap operations
    val iFunc: Option[Block[DeliteCollection[A]]] = None
    
    // symbol to iterate over the intermediate 
    // collection during flatmap operations
    val iF: Option[Sym[Int]] = None
    
    // size of the intermediate collection
    // for flatmap operations
    val sF: Option[Block[Int]] = None
    
    // symbol to hold the intermediate collection
    // during flatmap operations
    val eF: Option[Sym[DeliteCollection[A]]] = None
}
```
We immediately see what the first issue here is. The `MultiLoop` language as it is presented in [@eatperf] does not have enough expressive power to encode the semantics of `flatmap`. This leads to the strange encoding seen above, `iFunc` is set only in the cases where the operation produces a collection of elements per index of the loop. 

The second problem with the above encoding is not immediately obvious. The following example taken from [@betterfusion] illustrates the problem well.

```scala
val prod = arrayIf(10)({ i => i != 2 }, { i => i - 2 })
val cons = prod.fold(0.0, { (x,y) => x + 1.0/y })
```

The lowered consumer looks as follows [^1redesign]

```scala
SimpleLoop(prod.length, indexVar,
    DeliteFoldElem(0, cons, elemVal,
        { indexVar => prod.at(indexVar) }, // the map function
        { indexVar => cons + 1.0/elemVal }, // the reduce function
        Nil // no conditions yet
    )
)
```

After vertical fusion:

```scala
SimpleLoop(10, indexVar,
    DeliteFoldElem(0, cons, elemVal,
        { indexVar => indexVar - 2 }, // fused map      
        { indexVar => cons + 1.0/elemVal }, 
        List(indexVar != 2) // added condition
    )
)
```

The problem appears when we try to generate the code:

```scala
var cons = 0
for (indexVar <- 0 until 10) {
    val elemVal = indexVar - 2
    val res = cons + 1.0/elemVal
    val condition = (indexVar != 2)
    if (condition) cons = res
}
```

Even though the original code did not cause any error, the generated code causes a division by zero. We can try to fix this problem by always emitting the code for the condition first, and executing the rest of the code conditionally. This might generate some erroneous code however in the cases where the consumer contains a conditional. In the example below, the `print` statement is execute twice as often as it should.[^2redesign]

 

```scala
val prod = loop(10){i => {print(i); i + 1}
val cons = filter(prod)(_ % 2 == 0)
```

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

This duplication of code is due to the fact that the function and condition are emitted separately. The scheduler has no way to know that it is actually duplicating computation.

The work done by Vera Salvisberg in [@betterfusion] modifies the fusion algorithm in LMS to remove both these restrictions. It introduces the concept of `MultiCollect` as the base generator for loops. By default `MultiCollect` has the same semantics as `flatmap` in that it can produce multiple values on each iteration. But it can also be used to express filter and map as they are just specialized `flatmap` operations that produce one or less elements per iteration. This allows us to remove the need for an additional conditional field. It also provides the scheduler with all the information it needs to properly guard the computation of the current element while not duplicating computation.

We update the Delite `MultiLoop` language to reflect this change:

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

The implementation of the elems then becomes straightforward.

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

To avoid generating unnecessary code to allocate a useless intermediate collection in the map and filter case, we create extractors that let the code generators match on the shape of the current elem. 

```scala
abstract class DeliteCollectType

case class CollectMap(
    elem: Block[Any], 
    otherEffects: List[Exp[Any]]
) extends DeliteCollectType
        
case class CollectFilter(
    otherEffects: List[Exp[Any]], 
    cond: Exp[Boolean], 
    thenElem: Block[Any],
    thenEffects: List[Exp[Any]], 
    elseEffects: List[Exp[Any]]
) extends DeliteCollectType

case object CollectFlatMap extends DeliteCollectType

def getCollectElemType(
        collect: DeliteCollectBaseElem[_,_]) : DeliteCollectType
```


[^1redesign]: `DeliteFoldElem` is a version of the `Reduce` generator that can express the more general fold operation.

[^2redesign]: Scala has had a similar issue itself https://groups.google.com/forum/#!msg/scala-internals/sbvCLxPyDcA/6dr40vqUS40J 
