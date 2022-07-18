using Virtual
using Test


abstract type Animal end
struct Dog <: Animal end
struct Tiger <: Animal end
struct Duck <: Animal end

@testset "Virtual.jl" begin
    # Write your tests here.
    @virtual f(x, y) = y
    @override f(x, y::Int) = y + 3
    @test f(1, "2") === "2"
    @test f(1, 2) === 5




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

    samples = Animal[Dog(), Duck(), Tiger()]
    animals = Animal[samples[rand(1:3)] for i = 1:100]

    function sum_score(score_func, xs::AbstractVector{Animal})
        s = 0
        for x in xs
            s += score_func(x, 3)
        end
        return s
    end

    sum_score(fast_func, animals) == sum_score(manual_func, animals) == sum_score(dyn_func, animals)
end
