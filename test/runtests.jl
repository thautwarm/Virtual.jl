using Virtual
using Test

@testset "Virtual.jl" begin
    # Write your tests here.
    @virtual f(x, y) = y
    @override f(x, y::Int) = y + 3
    @test f(1, "2") === "2"
    @test f(1, 2) === 5
end
