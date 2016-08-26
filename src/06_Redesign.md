# Redesigning Delite Ops



```scala
trait DeliteLoopElem {
    val numDynamicChunks:Int
}

case class DeliteCollectElem[A, CA <: DeliteCollection[A]]] 
        extends Def[CA] with DeliteLoopElem {
        
    type I <: DeliteCollection[A]
    
    val func: Block[A]
    val cond: List[Block[Boolean]] = Nil
    
    val par: DeliteParallelStrategy
    val buf: DeliteBufferElem[A,I,CA]
    
    val iFunc: Option[Block[DeliteCollection[A]]] = None
    
    val iF: Option[Sym[Int]] = None
    val sF: Option[Block[Int]] = None
    val eF: Option[Sym[DeliteCollection[A]]] = None
}

case class DeliteReduceElem[A] 
        extends Def[A] with DeliteLoopElem {
    
    val func: Block[A]
    val cond: List[Block[Boolean]] = Nil
    val rFunc: Block[A]
    
    val stripFirst: Boolean
    val zero: Block[A]
    val accInit: Block[A]
    
    val rV: (Sym[A], Sym[A])
}
```

\pagebreak

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

case class DeliteReduceElem[A] {
    // The reduction function (associative!)
    rFunc: Block[A]
    
    // bound symbols for the reduction function arguments
    rV: (Sym[A], Sym[A])
}

case class DeliteFoldElem[A, O] extends DeliteCollectBaseElem[A, O]{
    // initializer for the accumulator
    init: Block[O]
    // True if init allocates a mutable accumulator, false otherwise
    mutable: Boolean
    // The parallel functions for each chunk: (A,O) => O
    foldPar: Block[O]
    // The sequential function for the chunk results: (O,O) => O
    redSeq: Block[O]
    // bound symbols for the foldPar function arguments
    fVPar: (Sym[O], Sym[A])
    // bound symbols for the redSeq function arguments
    rVSeq: (Sym[O], Sym[O])    
}
```