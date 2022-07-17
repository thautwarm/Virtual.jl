import Serialization

function create_exception(ln::LineNumberNode, reason::String)
    LoadError(string(ln.file), ln.line, ErrorException(reason))
end

"""
a slow replace and copy function used in compile time to reduce compilation latency.
"""
function replace_field(@nospecialize(x); @nospecialize(kwargs...))
    ns = fieldnames(typeof(x))
    ts = fieldtypes(typeof(x))
    fields = []
    for i in eachindex(ns, ts)
        n = ns[i]
        t = ts[i]
        if haskey(kwargs, n)
            push!(fields, convert(t, kwargs[n]))
        else
            push!(fields, getfield(x, n))
        end
    end
    typeof(x)(fields...)
end

const _using_runtime = Ref(false)
is_compile_time() = !_using_runtime[] && get(Base.ENV, "COMPILE_TIME", "") != ""

macro compile_only(ex)
    if is_compile_time()
        esc(ex)
    else
        :nothing
    end
end

macro compile_include(filename)
    filename = __module__.eval(filename)
    (filename_base, _) = splitext(filename)
    if !is_compile_time()
        fname = filename_base * ".compiled.jl"
        return esc(:($__module__.include($fname)))
    else
        src_filepath = joinpath(dirname(string(__source__.file)), filename)
        ast_filepath = joinpath(dirname(string(__source__.file)), filename_base * ".compiled.jlast")
        compiled_filepath = joinpath(dirname(string(__source__.file)), filename_base * ".compiled.jl")
        src_code = read(src_filepath, String)
        expr = Meta.parseall(src_code, filename=src_filepath)
        quote
            $Base.eval($__module__, $(QuoteNode(deepcopy(expr))))
            runtime_expr = try
                $_using_runtime[] = true
                $macroexpand($__module__, $(QuoteNode(expr)))
            finally
                $_using_runtime[] = false
            end
            $Serialization.serialize($ast_filepath, runtime_expr)
            $open($compiled_filepath, "w") do f
                $write(f, raw"""
import Serialization
let (_dirname, _filename) = splitdir(abspath(@__FILE__))
    local ast_filename = splitext(_filename)[1] * ".jlast"
    global expr = Serialization.deserialize(joinpath(_dirname, ast_filename))
    Base.eval((@__MODULE__), expr)
end
""")
            end
        end
    end
end