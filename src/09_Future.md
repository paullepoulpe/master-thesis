# Future

## CPU lowering pass

TODO: improve

Problems with fusion comes from the inability of the scheduler to see the different blocks that are composed together.

In the case of fusions, this caused wrong behaviors to occur, but more generally, the scheduler is missing optimization opportunities.

All the target languages that run on the CPU have roughly the same semantics. Composing the different blocks together into a lower language that follows those semantics would allow further optimization, and greatly reduce the complexity of the current code generator.

## Better reporting tools
When creating a new DSL, the programmer should be focused on functionality rather than performance. A DSL author should trust Delite to perform all of the necessary operations needed to make the resulting executable run as efficiently as possible. Currently however, there is no practical way to build this trust. To check weather a certain optimization has happened and why, the only information available is the resulting code. To understand the code, we need to understand the semantics of the Delite runtime. Even so, th
