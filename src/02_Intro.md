# Introduction

-- History of programming


Delite is a multi staging optimizing compiler architecture that takes high level domain specific language as input and produce high performance code for several different platform. Application programmers are most productive when they have access to the highest level of abstraction for their needs.

Every abstraction has a cost however. Whether it is function calls or composite data, every abstraction adds structure to the program, and that structure can get in the way of the optimizer. Furthermore, due to the wide variety of computing platforms available today, to obtain maximum performance (whether pure or performance per Watt), the compiler has to be aware of the platform specific semantics so it can specialize the program to take advantage of these differences.

Staging is a powerful and scalable solution that can be used to automatically strip abstraction from the program being staged and enable generic optimization to take place, making the resulting program as efficient as possible.

Staging alone is not sufficient though. Every modern programming language in use allows users to define loops of arbitrary sizes. It is therefore not possible to inline the entire program into one binary containing no branches nor function calls. There is a minimal necessary structure in the program that we cannot get rid of. Additionally, if we want to perform distributed computations for example, there are some optimization that cannot be performed statically but have to be handled by the runtime.

Because of these reasons, it becomes obvious the compiler needs to be aware of that structure and work around it. Specifically it must be able to reason about loops and access to structured data. In this report, we present two major optimizations that allow Delite to achieve the highest performance it can.

TODO: explain why loop fusion didn't work and had to be changed, and why that required a change to the delite ops

TODO: explain the problem with staging programs and how they are a pain to debug (find funny examples)


Our main contributions are:
 
 - Modify the delite architecture to integrate improvements made on the lms loop fusion
 - Improve the experience 

