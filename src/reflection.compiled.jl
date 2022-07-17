import Serialization
let (_dirname, _filename) = splitdir(abspath(@__FILE__))
    local ast_filename = splitext(_filename)[1] * ".jlast"
    global expr = Serialization.deserialize(joinpath(_dirname, ast_filename))
    Base.eval((@__MODULE__), expr)
end
