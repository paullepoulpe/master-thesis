# Abstract

 
 
## Outline (TODO: remove)

1. Abstract
    - trailer of what you did, why it was cool and what you learned)

2. Introduction // first paragraph part should look a lot like first paragraphs of delite papers
    - Start general (talk about programming language evolutions over the years)
    - Talk about abstraction
    - Talk about delite and how it is great and allows you to do cool things
    - Talk about loop fusion and Soa
    - on the way to loop fusion we discovered and adressed a need for better debugging / visualisation tools

3. Background & Theory // and related work
    - Keep it short for each project
    - Use all of the references
    - talk about delite
    - lms
    - parallel patterns
    - optimizations - soa
    - optimizations - loop fusion

4. LMS
    - How does lms work
    - What is the IR, how do transformations work

5. Delite
    - Parallel patterns in Delite

6. Delite Redesign
    - go into details of what had to be changed
    - How it used to be , how it is now

7. Delite tooling
    - What are the unique challenges when working with a staging compilers
    - Some techniques that can be used to tackle those challenges

5. Evaluation
    - amount of stuff that compiles -> was broken, is fixed
    - benchmarks with and wihtout certain optimizations -> was slow, is fast

6. Future Work
    - Lowering code to loop language -> mirror Introduction
    - Debugging and tooling future for staged programs (if I have time, find people who did simliar things )

7. Conclusion
    - abstract + first paragraph of intro