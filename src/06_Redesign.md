# Redesigning Delite Ops
```scala
case class DeliteCollectElem[A:Manifest, I <: DeliteCollection[A]:Manifest, CA <: DeliteCollection[A]:Manifest](
    func: Block[A],
    cond: List[Block[Boolean]] = Nil,
    par: DeliteParallelStrategy,
    buf: DeliteBufferElem[A,I,CA],
    iFunc: Option[Block[DeliteCollection[A]]] = None, //TODO: is there a cleaner way to merge flatMap functionality with Collect?
    iF: Option[Sym[Int]] = None,
    sF: Option[Block[Int]] = None,
    eF: Option[Sym[DeliteCollection[A]]] = None,
    numDynamicChunks: Int
  ) extends Def[CA] with DeliteLoopElem {
    val mA = manifest[A]
    val mI = manifest[I]
    val mCA = manifest[CA]
    val mDCA = manifest[DeliteCollection[A]]
  }
  ```