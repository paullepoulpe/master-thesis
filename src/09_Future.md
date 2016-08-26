# Future

## CPU lowering pass

TODO: improve

Problems with fusion comes from the inability of the scheduler to see the different blocks that are composed together.

In the case of fusions, this caused wrong behaviours to occur, but more generally, the scheduler is missing optimization opportunities.

All the target languages that run on the CPU have roughly the same semantics. Composing the different blocks together into a lower language that follows those semantics would allow further optimization, and greatly reduce the complexity of the current code generator.
