@compile_only using MLStyle
struct Undefined end

const NullSymbol = Union{Symbol, Undefined}
const _undefined = Undefined()
const PVec{T, N} = NTuple{N, T}
const _pseudo_line = LineNumberNode(1)

Base.@kwdef struct TypeRepr
    base :: Any = _undefined
    typePars :: PVec{TypeRepr} = ()
end

to_expr(t::TypeRepr) =
    if isempty(t.typePars)
        t.base
    else
        :($(t.base){$(to_expr.(t.typePars)...)})
    end

Base.@kwdef mutable struct ParamInfo
    name :: Any = _undefined
    type :: Any = _undefined
    defaultVal :: Any = _undefined
    meta :: Vector{Any} = []
    isVariadic :: Bool = false
end

function to_expr(p::ParamInfo)
    res = if p.name isa Undefined
        @assert !(p.type isa Undefined)
        :(::$(p.type))
    else
        if p.type isa Undefined
            p.name
        else
            :($(p.name)::$(p.type))
        end
    end
    if p.isVariadic
        res = Expr(:..., res)
    end
    if !(p.defaultVal isa Undefined)
        res = Expr(:kw, res, p.defaultVal)
    end
    if !isempty(p.meta)
        res = Expr(:meta, p.meta..., res)
    end
    return res
end

Base.@kwdef struct TypeParamInfo
    name :: Symbol
    lb :: Union{TypeRepr, Undefined} = _undefined
    ub :: Union{TypeRepr, Undefined} = _undefined
end

function to_expr(tp::TypeParamInfo)
    if tp.lb isa Undefined
        if tp.ub isa Undefined
            tp.name
        else
            :($(tp.name) <: $(to_expr(tp.ub)))
        end
    else
        if tp.ub isa Undefined
            :($(tp.name) >: $(to_expr(tp.lb)))
        else
            :($(to_expr(tp.lb)) <: $(tp.name) <: $(to_expr(tp.ub)))
        end
    end
end

Base.@kwdef mutable struct FuncInfo
    ln :: LineNumberNode = _pseudo_line
    name :: Any = _undefined
    pars :: Vector{ParamInfo} = ParamInfo[]
    kwPars :: Vector{ParamInfo} = ParamInfo[]
    typePars :: Vector{TypeParamInfo} = TypeParamInfo[]
    returnType :: Any = _undefined # can be _undefined
    body :: Any = _undefined # can be _undefined
    isAbstract :: Bool = false
end

function to_expr(f::FuncInfo)
    if f.isAbstract
        return :nothing
    else
        args = []
        if !isempty(f.kwPars)
            kwargs = Expr(:parameters)
            push!(args, kwargs)
            for each in f.kwPars
                push!(kwargs.args, to_expr(each))
            end
        end
        for each in f.pars
            push!(args, to_expr(each))
        end
        header = if f.name isa Undefined
           Expr(:tuple, args...)
        else
            Expr(:call, f.name, args...)
        end
        if !(f.returnType isa Undefined)
            header = :($header :: $(f.returnType))
        end
        if !isempty(f.typePars)
            header = :($header where {$(to_expr.(f.typePars)...)})
        end
        return Expr(:function, header, f.body)
    end
end

function parse_type_repr(ln::LineNumberNode, repr)
    @switch repr begin
        @case :($typename{$(generic_params...)})
            return TypeRepr(typename, Tuple(parse_type_repr(ln, x) for x in generic_params))
        @case typename
            return TypeRepr(typename, ())
        @case _
            throw(create_exception(ln, "invalid type representation: $repr"))
    end
end


function parse_parameter(ln :: LineNumberNode, p; support_tuple_parameters=true)
    self = ParamInfo()
    parse_parameter!(ln, self, p, support_tuple_parameters)
    return self
end

function parse_parameter!(ln :: LineNumberNode, self::ParamInfo, p, support_tuple_parameters)
    @switch p begin
        @case Expr(:meta, x, p)
            push!(self.meta, x)
            parse_parameter!(ln, self, p, support_tuple_parameters)
        @case Expr(:..., p)
            self.isVariadic = true
            parse_parameter!(ln, self, p, support_tuple_parameters)
        @case Expr(:kw, p, b)
            self.defaultVal = b
            parse_parameter!(ln, self, p, support_tuple_parameters)
        @case :(:: $t)
            self.type = t
            nothing
        @case :($p :: $t)
            self.type = t
            parse_parameter!(ln, self, p, support_tuple_parameters)
        @case p::Symbol
            self.name = p
            nothing
        @case Expr(:tuple, _...)
            if support_tuple_parameters
                self.name = p
            else
                throw(create_exception(ln, "tuple parameters are not supported"))
            end
            nothing
        @case _
            throw(create_exception(ln, "invalid parameter $p"))
    end
end

function parse_type_parameter(ln :: LineNumberNode, t)
    @switch t begin
        @case :($lb <: $(t::Symbol) <: $ub) || :($ub >: $(t::Symbol) >: $lb)
            TypeParamInfo(t, parse_type_repr(ln, lb), parse_type_repr(ln, ub))
        @case :($(t::Symbol) >: $lb)
            TypeParamInfo(t, parse_type_repr(ln, lb), _undefined)
        @case :($(t::Symbol) <: $ub)
            TypeParamInfo(t, _undefined, parse_type_repr(ln, ub))
        @case t::Symbol
            TypeParamInfo(t, _undefined, _undefined)
        @case _
            throw(create_exception(ln, "invalid type parameter $t"))
    end
end

function parse_function(ln :: LineNumberNode, ex; fallback :: T = _undefined,  allow_short_func :: Bool = false, allow_lambda :: Bool = false) where T
    self :: FuncInfo = FuncInfo()
    @switch ex begin
        @case Expr(:function, header, body)
            self.body = body
            self.isAbstract = false # unnecessary but clarified
            parse_function_header!(ln, self, header; is_lambda = false, allow_lambda = allow_lambda)
            return self
        @case Expr(:function, header)
            self.isAbstract = true
            parse_function_header!(ln, self, header; is_lambda = false, allow_lambda = allow_lambda)
            return self
        @case Expr(:(->), header, body)
            if !allow_lambda
                throw(create_exception(ln, "lambda functions are not allowed here: $ex"))
            end
            self.body = body
            self.isAbstract = false
            parse_function_header!(ln, self, header; is_lambda = true, allow_lambda = true)
            return self
        @case Expr(:(=), Expr(:call, _...) && header, rhs)
            if !allow_short_func
                throw(create_exception(ln, "short functions are not allowed here: $ex"))
            end
            self.body = rhs
            self.isAbstract = false
            parse_function_header!(ln, self, header; is_lambda = false, allow_lambda = false)
            return self
        @case _
            if fallback isa Undefined
                throw(create_exception(ln, "invalid function expression: $ex"))
            else
                fallback
            end
    end
end

function parse_function_header!(ln::LineNumberNode, self::FuncInfo, header; is_lambda :: Bool = false, allow_lambda :: Bool = false)
    typePars = self.typePars

    @switch header begin
        @case Expr(:where, header, tyPar_exprs...)
            for tyPar_expr in tyPar_exprs
                push!(typePars, parse_type_parameter(ln, tyPar_expr))
            end
        @case _
    end

    @switch header begin
        @case Expr(:(::), header, returnType)
            FuncInfo.returnType = returnType
        @case _
    end

    if is_lambda && !Meta.isexpr(header, :tuple)
        header = Expr(:tuple, header)
    end

    @switch header begin
        @case Expr(:call, f, Expr(:parameters, kwargs...), args...)
            for x in kwargs
                push!(self.kwPars, parse_parameter(ln, x))
            end
            for x in args
                push!(self.pars, parse_parameter(ln, x))
            end
            self.name = f
        @case Expr(:call, f, args...)
            for x in args
                push!(self.pars, parse_parameter(ln, x))
            end
            self.name = f
        @case Expr(:tuple, Expr(:parameters, kwargs...), args...)
            if !allow_lambda
                throw(create_exception(ln, "tuple function signature are not allowed here."))
            end
            for x in kwargs
                push!(self.kwPars, parse_parameter(ln, x))
            end
            for x in args
                push!(self.pars, parse_parameter(ln, x))
            end
        @case Expr(:tuple, args...)
            if !allow_lambda
                throw(create_exception(ln, "tuple function signature are not allowed here."))
            end
            for x in args
                push!(self.pars, parse_parameter(ln, x))
            end
        @case _
            if !self.isAbstract
                throw(create_exception(ln, "unrecognised function signature $header."))
            else
                self.name = header
            end

    end
end