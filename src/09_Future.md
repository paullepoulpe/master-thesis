
# Future

## CPU lowering pass
In this report, we haven't discussed in detail how Delite `Ops` are generated. We just assumed that such a generator exists. In practice, this step can be quite complex. Each element that is emitted needs to respect the specific semantics of the target as well as understand how to interact with the Delite runtime. Furthermore, because the generator only emits one element of the loop at a time, it might miss some optimization opportunities. The same phenomenon happened with the old version of loop fusion.

All the target languages (scala, CPP) that run on the CPU have resembling semantics. There are likely similar enough that they can be both expressed in a common language. This language would translate all of the `MultiLoop` constructs into simpler loops, transforming all of the `Elem`s into generic code with no special semantic.

These changes would allow the code generation step to become a lot simpler as it would only need to understand the specific semantics of the Delite runtime. It would also unify each of the `Elem`'s fields into a unique scope, giving further optimization opportunities to the scheduler.

## Reporting tools
A DSL user should be able to trust that Delite is doing all it can to optimize the program and generate efficient code. Currently however, there is no practical mechanism to verify what kind of optimizations have been run. 

One can run the compiler twice with different settings, but the outputs might be vastly different. Another solution would be to run benchmarks to observe the effects of the transformations at runtime, however this might take a long time. Furthermore, neither of those methods provide any measure of the optimizations performed (number of fused loops, number of `SoA`ed arrays).

Extending the current set of tools to support that kind of analysis to be performed could be very useful. Not only reassuring the DSL author and users that their code is efficient, but also for Delite maintainers to make sure that any change they make does not cause a performance regression.

## Optimization benefits
The experiments we performed revealed something interesting. On our example, fusion alone did not seem to provide any substantial benefits, sometimes actually adding some overhead to the code. This is surprising since vertical fusion removes intermediate collections, we would expect a net positive improvement compared to the baseline. Furthermore, fusion is enabled by default in Delite, which suggests that is it assumed be beneficial.

Revisiting this assumption and understanding in details what conditions are required for loop fusion to provide faster resulting code could allow Delite to achieve higher performance.