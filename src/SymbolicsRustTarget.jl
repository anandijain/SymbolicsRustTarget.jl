module SymbolicsRustTarget
using Symbolics
using Symbolics: BuildTargets, buildvarnumbercache, numbered_expr, value, toexpr, coperators
struct RustTarget <: BuildTargets end

"""
Build function target: `RustTarget`

```julia
function _build_function(target::RustTarget, ex::AbstractArray, args...;
                         columnmajor = true,
                         conv        = toexpr,
                         expression  = Val{true},
                         fname       = :diffeqf,
                         lhsname     = :du,
                         rhsnames    = [Symbol("rhs\$i") for i in 1:length(args)],
                         libpath     = tempname(),
                         compiler    = :gcc)
```

This builds an in-place C function. Only works on expressions. If
`expression == Val{false}`, then this builds a function in C, compiles it,
and returns a lambda to that compiled function. These special keyword arguments
control the compilation:

- libpath: the path to store the binary. Defaults to a temporary path.
- compiler: which C compiler to use. Defaults to :gcc, which is currently the
  only available option.
"""
function Symbolics._build_function(target::RustTarget, ex::AbstractArray, args...;
    columnmajor=true,
    conv=toexpr,
    expression=Val{true},
    fname=:diffeqf,
    lhsname=:du,
    rhsnames=[Symbol("rhs$i") for i in 1:length(args)],
    libpath=tempname(),
    compiler=:gcc)

    equations = c_rust_get_equations(target, ex, args...;
        columnmajor,
        conv,
        expression,
        fname,
        lhsname,
        rhsnames,
        libpath,
        compiler)

    argstrs = join(vcat("$(lhsname): &mut [f64; $(length(ex))]", [typeof(args[i]) <: AbstractArray ? "$(rhsnames[i]): &[f64; $(length(args[i]))]" : "$(rhsnames[i]): &f64" for i in 1:length(args)]), ", ")
    sig = "pub fn $fname($(argstrs...)) -> ()"
    ccode = """
    $sig {$([string("\n  ", eqn) for eqn ∈ equations]...)\n}
    """
    # if you wanted to use CTarget and rust FFI
    # ccode2 = """
    # extern "C" {
    #     fn $fname($(argstrs...)) -> ();
    # }
    # """
    ccode = replace(ccode, "-1 * " => "-1. * ") # no float*int in rust
    ccode = replace(ccode, "1 * " => " 1. * ")

    return ccode
end
_build_function(target::RustTarget, ex::Num, args...; kwargs...) = _build_function(target, [ex], args...; kwargs...)
# signature(_::RustTarget, ex, args, lhsname, rhsnames) = join(vcat("$(lhsname): &mut [f64; $(length(ex))]", [typeof(args[i]) <: AbstractArray ? "$(rhsnames[i]): &[f64; $(length(args[i]))]" : "$(rhsnames[i]): &f64" for i in 1:length(args)]), ", ")

function c_rust_get_equations(target::Union{Symbolics.CTarget,RustTarget}, ex::AbstractArray, args...;
    columnmajor=true,
    conv=toexpr,
    expression=Val{true},
    fname=:diffeqf,
    lhsname=:du,
    rhsnames=[Symbol("rhs$i") for i in 1:length(args)],
    libpath=tempname(),
    compiler=:gcc)

    if !columnmajor
        return _build_function(target, hcat([row for row ∈ eachrow(ex)]...), args...;
            columnmajor=true,
            conv=conv,
            fname=fname,
            lhsname=lhsname,
            rhsnames=rhsnames,
            libpath=libpath,
            compiler=compiler)
    end


    varnumbercache = buildvarnumbercache(args...)
    equations = Vector{String}()
    for col ∈ 1:size(ex, 2)
        for row ∈ 1:size(ex, 1)
            lhs = string(lhsname, "[", (col - 1) * size(ex, 1) + row - 1, "]")
            rhs = numbered_expr(value(ex[row, col]), varnumbercache, args...;
                      lhsname=lhsname,
                      rhsnames=rhsnames,
                      offset=-1) |> coperators |> string  # Filter through coperators to produce valid C code in more cases
            push!(equations, string(lhs, " = ", rhs, ";"))
        end
    end
    equations
end

end # module
