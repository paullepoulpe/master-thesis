# Tooling for Delite
In this section we present some of the problems we discovered working with delite. We first explain why those challenges are unique to the arcitecture of a staging compiler. We then present solutions we designed and prototyped to tackle these challenges.

## `Sym` to `Def` relationship
There are several techniques that can be used to examine why a program is misbehaving. 

We call the first approach the "Logpocalypse" technique. This method consists of inserting additional code to the program that will print out the state we are interested in examining through the execution of the program. This has several drawbacks however: the first one is that we incur a compilation overhead everytime we want to inspect a different part of the state; another one is that some classes of bugs such as heisenbugs [^4] can be significantly harder to study with this approach.



An more powerful approach to tackle software bugs is by using a debugger. A debugger
allows us to interrupt the program at the moment when a sympom occurs, and examine the program's internal state (local variables, call trace) that causes the symptom to occur.

Both method have their advantages [@debug]. However, the logging method is significantly easier to implement withtout the support of a specialized tool. Furthermore, because of the structure of the LMS framework, we found it is in practice quite difficult to extract useful information about the structure of the program being staged. The abstractions used by LMS itself to represent the IR and the relationship between symbols and defitions get in the way of the debugger. A general purpose debugger is therefore not practical when it comes to LMS.

## IR ordering
As we have seen in previous sections, the "sea of nodes" representation used by LMS for its IR enables some poewrful optimizations. Since there is no explicit ordering of the statements until a traversal is required, it allows the scheduler to reorder statements and reduce frequency of execution of expensive operation by hoisting them out of their scope.

This representation however presents some unique challenges when debugging the code. Becuase all of the node dependencies are expressed by DSL authors through the `syms` function, it is vulnerable to human error. This means that a programming mistake can result in a bug that would cause the scheduler to produce some invalid ordering. We soon realized that finding the root cause of this type of error can be challenging.

The single most common symptom of this class of bug is an order violation of effects. The reason behind is due to the mechanism the scheduler uses to sanity check the validity of schedules. To track side effects within scopes, LMS summarizes them in `Reify` blocks, the scheduler can then make sure that all of the effects are accounted for when it is building the schedule for the block's result. There is no other mechanism in LMS to check the sanity of a schedule, and ther is no practical way to explore the dependencies between nodes

## Phase separation
LMS uses type information to differentiate between values of different stages (`Rep[T]` vs `T`). Every element that is not of the form `Rep[T]` becomes a constant in subsequent stages. While LMS enforces strict separation between stages, there are still potentially several transformations happenning within the same stage. Following common terminology in the compiler community we will call the result obtained between transformations a phase.

Because of its immutable "sea of nodes" representation. There is no clear separation between different phases of a single stage. As we have discussed in a previous chapter, each transformer doesn't create a well defined set of statements for each phase, it only adds new transformed and mirrored statement to the global set for the current stage.

When working with program transformations, this can become a real challenge. The substitutions and transformations are not apparent when inspecting the list of statements composing the IR.

In the follwoing sections, we present the tools that we create over the course of this project to address the issues presented above.

## lms-debugger

As a solution to our first problem, we propose a context-aware debugger for LMS[^5]. Using the general purpose scala-debugger project[^6] to provide basic debugging capabilities, we extend it with utilities that can understand the semantics of LMS's data structures. We add some capabilities that allow us to reify locally values from the target process.

TODO: details of implementation ??

## lms-visualisation

The second tool we present started as a simple visualisation tool[^7] for transformation passes. By using it, we later discovered that it could also be used as a practical way to query useful information about the IR that can be used to debug transformations efficiently. 

The tool is made of two separate part, a logger and a visualiser. The logger extracts the IR and all of the statemnts' dependencies along with their source information from LMS in a text format. This format can then easily be consumed by the visualiser to present useful information about the compilation pipeline. We designed it this way to decouple it from LMS's internal implementation. The only assumption we make is about the format of the IR. We believe that this assumption to be sound. Since a lot of project heavily rely on LMS, Delite being one example, the engineering effort needed to change the IR would be significant and thus unlikely. 

To allow programmers familiar with LMS to modify our tool, we used `Scala.js`[^8] for our user interface. This removes the language barrier that might otherwise prevent other people from improving on our design. 

We also provide a command line interface to query the dependencies between nodes of the IR. It provides utilities to resolve definitions from symbols, find dependencies for a particular symbol, and find arbitrary dependency chains between symbols. As this is still a prototype, there is some room for progress. The limited functionality the tool proved to be very useful nevertheless.


[^4]: Named from Heisenberg's Uncertainty Principle in quantum physics, a heiseinbug is a bug that disappears or alters its behavior when one attempts to probe or isolate it.
[^5]: Available at https://github.com/Stanford-PDM/lms-debugger
[^6]: Available at http://scala-debugger.org/
[^7]: Available at https://github.com/Stanford-PDM/lms-visualisation
[^8]: Available at http://www.scala-js.org/