# Tooling for Delite
In this section we present some of the problems we discovered working with delite. We first explain why those challenges are unique to the architecture of a staging compiler. We then present solutions we designed and prototyped to tackle these challenges.

## `Sym` to `Def` relationship
There are several techniques that can be used to examine why a program is misbehaving. 

We call the first approach the "Logpocalypse" technique. This method consists of inserting additional code to the program that will print out the state we are interested in examining through the execution of the program. This has several drawbacks however: the first one is that we incur a compilation overhead every time we want to inspect a different part of the state; another one is that some classes of bugs such as heisenbugs [^4] can be significantly harder to study with this approach.

A more powerful approach to tackle software bugs is by using a debugger. A debugger
allows us to interrupt the program at the moment when a symptom occurs, and examine the program's internal state (local variables, call trace) that causes the symptom to occur.

Both methods have their advantages [@debug]. However, the logging method is significantly easier to implement without the support of a specialized tool. Furthermore, because of the structure of the LMS framework, we found it is in practice quite difficult to extract useful information about the structure of the program being staged. The abstractions used by LMS itself to represent the IR and the relationship between symbols and definitions get in the way of the debugger. A general purpose debugger is therefore not practical when it comes to LMS.

## IR ordering
As we have seen in previous sections, the "sea of nodes" representation used by LMS for its IR enables some powerful optimizations. Since there is no explicit ordering of the statements until a traversal is required, it allows the scheduler to reorder statements and reduce frequency of execution of expensive operations by hoisting them out of inner scopes.

This representation however presents some unique challenges when debugging the code. Because all of the node dependencies are expressed by DSL authors through the `syms` function, it is vulnerable to human error. This means that a programming mistake can result in a bug that would cause the scheduler to produce some invalid ordering. We soon realized that finding the root cause of this type of error can be challenging.

The single most common symptom of this class of bug is an order violation of effects. The reason behind is due to the mechanism the scheduler uses to sanity check the validity of schedules. To track side effects within scopes, LMS summarizes them in `Reify` blocks, the scheduler can then make sure that all of the effects are accounted for when it is building the schedule for the block's result. There is no other mechanism in LMS to check the sanity of a schedule, and there is no practical way to explore the dependencies between nodes

## Phase separation
LMS uses type information to differentiate between values of different stages (`Rep[T]` vs `T`). Every element that is not of the form `Rep[T]` becomes a constant in subsequent stages. While LMS enforces strict separation between stages, there are still potentially several transformations happening within the same stage. Following common terminology in the compiler community we will call the result obtained between transformations a phase.

Because of its immutable "sea of nodes" representation. There is no clear separation between different phases of a single stage. As we have discussed in a previous chapter, each transformer doesn't create a well defined set of statements for each phase, it only adds new transformed and mirrored statement to the global set for the current stage.

When working with program transformations, this can become a real challenge. The substitutions and transformations are not apparent when inspecting the list of statements composing the IR.

In the following sections, we present the tools that we create over the course of this project to address the issues presented above.

## `lms-debugger`

As a solution to our first problem, we propose a context-aware debugger for LMS[^5]. Using the general purpose `scala-debugger` project[^6] to provide basic debugging capabilities, we extend it with utilities that can understand the semantics of LMS's data structures. We add some capabilities that allow us to reify locally values from the target process.

The most basic feature the tool provides is, like any other debugger, the ability to stop the target code at any point.

```scala
scala> break("CodeMotion.scala", 14)
...
Breakpoint set at 
        scala/virtualization/lms/internal/CodeMotion.scala:14
```

By providing the source folders, the tool can examine the source and figure out the fully qualified name for any file provided.

```scala
scala> Hit breakpoint at CodeMotion.scala:14
```

We then provide two different apis that can be used to inspect the state of the target. By using the `scala.Dynamic` type provided by scala, we are able to create a simple embedded language in the scala interpreter that can be used to retrieve values from the target process.

```scala
scala> p()
$this = Instance of scala.virtualization.lms.util.ExportTransfo ...
currentScope = Instance of scala.collection.immutable.$colon$co ...
result = Instance of scala.collection.immutable.$colon$colon (0 ...

scala> p(_.currentScope)
currentScope = $colon$colon(
  head = Instance of scala.virtualization.lms.internal.Expressi ...
  tl = Instance of scala.collection.immutable.$colon$colon (0x273B)
)
```

The second api is enhanced with semantics about certain types and utility functions. In the following snippet for example it can recognize a value of type `List` and reify it locally.

```scala
scala> &.currentScope
res3: org.lmsdbg.utils.DynamicWrappers.Scope = List(...)

scala> &.currentScope.asList
res4: List[org.lmsdbg.utils.DynamicWrappers.LMSValueScope] = 
List(class Expressions$TP{sym = Sym(5), rhs = Instance of scal ...
```

By installing a hook on the definition registration function of LMS, the tool is able to track the relationship between symbols and definitions. When it encounters a value of type `Sym`, it uses that information to automatically retrieve the corresponding definition. In case we actually wanted to inspect the symbol, we provide a helper function that can be used to retrieve the symbol identifier.

```scala
scala> &.currentScope.asList.map(_.sym)
res5: List[org.lmsdbg.utils.DynamicWrappers.Scope] = 
List(class Effects$Reflect{x = Instance of ppl.delite.framewor ...

scala> &.currentScope.asList.map(_.sym.symbolId)
res6: List[Option[Int]] = List(Some(5), Some(6), ...)
```

## `lms-visualisation`

The second tool we present started as a simple visualization tool[^7] for transformation passes. By using it, we later discovered that it could also be used as a practical way to query useful information about the IR that can be used to debug transformations efficiently. 

The tool is made of two separate parts, a logger and a visualizer. The logger extracts the IR and all of the statements' dependencies along with their source information from LMS in a text format. This format can then easily be consumed by the visualizer to present useful information about the compilation pipeline. We designed it this way to decouple it from LMS's internal implementation. The only assumption we make is about the format of the IR. We believe that this assumption to be sound. Since a lot of project heavily rely on LMS, Delite being one example, the engineering effort needed to change the IR would be significant and thus unlikely. 

To allow programmers familiar with LMS to modify our tool, we used `Scala.js`[^8] for our user interface. This removes the language barrier that might otherwise prevent other people from improving on our design.

Using the generate trace, our tool produces a graphical interface presenting a representation of the compilation pipeline. The user can inspect the current transformation or move to the next one. Each transformation is represented as two semi-structured list of statements. Each list corresponds to a valid schedule of the program, one before, and the other after the transformation. The lists are semi structured, because they only present the statements that are in the top most scope of the IR. By clicking on an element, we expose the statements in the inner scopes of that definition. 

Even though we have not run into any transformer that was not a substitution
transformer, in theory, there are no strong constraints on the kind of transformers that can be expressed with LMS. To understand the effects of a transformer despite this limitation, we use the `SourceContext` information available in each symbol of the IR. Since each symbol tracks the transformations it has gone through during compilation, we can perform a simple comparison to understand how symbols are related across transformer passes. Using this simple mechanism, the tool will highlight all of the statements that might be related to the current focused statement. It will also expand any scope necessary to make related symbols visible.

We also provide a command line interface to query the dependencies between nodes of the IR. It provides utilities to resolve definitions from symbols, find dependencies for a particular symbol, and find arbitrary dependency chains between symbols. As this is still a prototype, there is some room for progress. The limited functionality the tool proved to be very useful nevertheless.


[^4]: Named from Heisenberg's Uncertainty Principle in quantum physics, a heisenbug is a bug that disappears or alters its behavior when one attempts to probe or isolate it.
[^5]: Available at https://github.com/Stanford-PDM/lms-debugger
[^6]: Available at http://scala-debugger.org/
[^7]: Available at https://github.com/Stanford-PDM/lms-visualisation
[^8]: Available at http://www.scala-js.org/
