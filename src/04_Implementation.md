# Lightweight Modular Staging
To explain the design of the Delite framework, we first have to take a step back and explain the inner workings of LMS. This section explains in detail the intermediate representation (IR) that LMS uses to model computations. We also briefly explain the mechanism that used to create to lift program into IR as well as the interface used to express IR transformations.

## Sea of Nodes
The format that LMS uses [@lms] for it's IR is based on expression trees and single static assignments (SSA). More exactly, it uses what is called a "sea of nodes" representaiton. 

The IR is composed of a collection of statements, or typed pair (TP). Every pair contains a symbol and a definition. A symbol is a simple reference to the statement it defines. Definitions are used to express how expressions can be combined. Expressions are restricted to symbols and constants. The typing information is expressed using scala's type system and in a typeclass within each symbol.

Here is a summary of the types used in the IR:

```scala
trait Exp[+T]

// Constant expression of type T
case class Const[T](x: T) extends Exp[T]
// Symbol referencing a definition of type T        
case class Sym[T](id: Int) extends Exp[T]  

// Composite node that is defined by a library or DSL author
trait Def[+T]

// Statement in the IR
case class TP[+T](sym: Sym[T], rhs: Def[T])
```


`Exp[T]` is an interface that represents an expression of type `T`. Constants and symbols are the only elements implementing that interface. Composite operations are defined using `Def`s and can only reference symbols or constants. All the symbols that are referenced by a definition are called it's dependencies and get be queried through the `syms` function.

During program evaluation, each definition is associated with a symbol, and that symbol is returned in place of the value for use in subsequent operations (see [@virtualization] & [@tagless] for the mechanism through which this is achieved). This allows LMS to automatically perform common subexpression elimination (CSE) on the IR. Every repeated definition in the user's program will be associated with the same symbol in the generated IR. To illustrate how it works, consider the following example.

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

The resulting IR would ressemble something like this

```scala
TP(Sym(1), IntPlus(Sym(0), Const(2)))
TP(Sym(2), OrderingGT(Sym(1), Const(13)))
TP(Sym(3), IntTimes(Sym(1), Const(3)))
TP(Sym(4), IfThenElse(Sym(2), Sym(3), Sym(1)))
```

As we can see, the computation for `x1` has not been duplicated for `x1bis` because it is the same, LMS returned `Sym(1)` in the `IfThenElse` definition.

## Scheduling
Since there is no explicit ordering of statements in the IR, we need an additional step to generate code. This step is called scheduling. Starting from the result expression of the program, the scheduler walks the list of dependencies backwards to collect all of the 
statements that will compose the program. It then sorts them in order such that any statement comes after it's dependencies. The resulting schedule can then be used to generate code that will respect the semantics of the original program.

## Scopes
Since the


## Transformers and Mirroring
As we've seen in the previous section, LMS can automatically perform generic optimization. For more specific optimizations, LMS provides a transformation API.

A transformer walks through a schedule and processes each statement to decide whether it has to be changed or not. Even when a statement is not modified by the transformer, it's dependencies might have been and that has to be reflected in the node. In LMS, this process is called mirroring.

Since the AST is immutable, mirroring has to generate a new node with the updated dependencies. The mirroring function also has the opportunity to perform domain specific optimization when generating the node depending on changes made to the dependencies.