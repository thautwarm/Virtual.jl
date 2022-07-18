using Virtual, BenchmarkTools
abstract type Animal end
struct Dog <: Animal end
struct Tiger <: Animal end
struct Duck <: Animal end

@virtual fast_func(x::Animal, y::Int) = error("No default method for score!")
@override fast_func(x::Dog, y::Int) = 2 + y
@override fast_func(x::Tiger, y::Int) = 3 + y
@override fast_func(x::Duck, y::Int) = 4 + y

dyn_func(x::Animal, y::Int) = error("No default method for score!")
dyn_func(x::Dog, y::Int) = 2 + y
dyn_func(x::Tiger, y::Int) = 3 + y
dyn_func(x::Duck, y::Int) = 4 + y

manual_func(x::Animal, y::Int) =
    if x isa Dog
        2 + y
    elseif x isa Tiger
        3 + y
    elseif x isa Duck
        4 + y
    else
        error("No default method for score!")
    end

const samples = Animal[Dog(), Duck(), Tiger()]
animals = Animal[samples[rand(1:3)] for i = 1:100]

function sum_score(score_func, xs::AbstractVector{Animal})
    s = 0
    for x in xs
        s += score_func(x, 3)
    end
    return s
end

@info "fast_func via Virtual.jl"
display(@benchmark(sum_score(fast_func, animals)))
@info "manual split by hand"
display(@benchmark(sum_score(manual_func, animals)))
@info "dyn_func by dynamic multiple dispatch"
display(@benchmark(sum_score(dyn_func, animals)))
