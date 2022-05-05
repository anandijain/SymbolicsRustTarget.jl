using Symbolics, SymbolicsRustTarget
using Test

function f(du, u, p, t)
    du[1] = p[1] * (u[2] - u[1])
    du[2] = u[1] * (p[2] - u[3]) - u[2]
    du[3] = u[1] * u[2] - p[3] * u[3]
end

@variables du[1:3] u[1:3] p[1:3]
du = collect(du)
u = collect(u)
p = collect(p)
t = 0
f(du, u, p, t)

r_str = build_function(du, u, p, t; target=SymbolicsRustTarget.RustTarget())
write(joinpath(@__DIR__, "rust_target/src/lib.rs"), r_str)

wait(run(`cargo run --manifest-path rust_target/Cargo.toml`))
@test read("foo.txt", String) == "[-1.0, 1.0, 0.0] [1.0, 0.0, 0.0] [1.0, 1.0, 1.0] 0.0"
