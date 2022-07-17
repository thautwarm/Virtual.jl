using Virtual
using MLStyle
using BenchmarkTools

abstract type Animal end
mutable struct Dog <: Animal end
mutable struct Duck <: Animal end
mutable struct Tiger <: Animal end
mutable struct IntBox
    i :: Int
end
@virtual score(x::Animal, y::IntBox) = error("unknown animal $x")
# score(Dog())
# # println(@macroexpand @virtual f(x) = 1)

@override score(x::Dog, y::IntBox) = 2 + y.i
@override score(x::Duck, y::IntBox) = 3 + y.i
@override score(x::Tiger, y::IntBox) = 6 + y.i
@override score(x::Tiger, y::IntBox) = 4 + y.i

novirt_score(x::Dog, y::IntBox) = 2 + y.i
novirt_score(x::Duck, y::IntBox) = 3 + y.i
novirt_score(x::Tiger, y::IntBox) = 4 + y.i

dir_score(x::Animal, y::IntBox) =
    if x isa Dog
        2 + y.i
    elseif x isa Duck
        3 + y.i
    elseif x isa Tiger
        4 + y.i
    else
        error("unknown animal $x")
    end

function sum_score(score_func, xs::AbstractVector{Animal})
    s = 0
    u = IntBox(3)
    for x in xs
        s += score_func(x, u)
    end
    return s
end

const samples = Animal[Dog(), Duck(), Tiger()]
animals = Animal[samples[rand(1:3)] for i = 1:100]

# gen_score(x::Animal, y::IntBox) = Virtual.apply_switch(
#     Tuple{
#         Tuple{typeof(score), Dog, IntBox}, 
#         Tuple{typeof(score), Duck, IntBox}, 
#         Tuple{typeof(score), Tiger, IntBox},
#         Tuple{typeof(score), Animal, IntBox}},
#     (x, y)
# )
# code_typed(
#     Virtual.apply_switch,
#     (
#         Type{Tuple{
#             Tuple{typeof(score), Dog, IntBox}, 
#             Tuple{typeof(score), Duck, IntBox}, 
#             Tuple{typeof(score), Tiger, IntBox},
#             Tuple{typeof(score), Animal, IntBox}}},
#         Tuple{Animal, Int}
#     )) |> display
    

println(sum_score(score, animals))
println(sum_score(novirt_score, animals))
using InteractiveUtils
# code_warntype(score, (Animal, Int))
display(code_llvm(score, (Dog, IntBox)))
# # # display(code_typed(score, (Animal, )))
code_typed(score, (Animal, IntBox)) |> display

display(@benchmark sum_score(dir_score, animals))
# # display(@benchmark sum_score(gen_score, animals))
display(@benchmark sum_score(score, animals))
# display(@benchmark sum_score(novirt_score, animals))

