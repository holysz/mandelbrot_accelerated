using GLMakie

function mandelbrot(x, y)
    z = c = x + y * im
    for i in 1:30.0 abs(z) > 2 && return i; z = z ^ 2 + c; end; 0
end

mandelbrot(0,0)

x = LinRange(-2, 1, 200)
y = LinRange(-1.1, 1.1, 200)
matrix = mandelbrot.(x, y')
fig, ax, hm = heatmap(x, y, matrix)

N = 50
xmin = LinRange(-2.0, -0.72, N)
xmax = LinRange(1, -0.6, N)
ymin = LinRange(-1.1, -0.51, N)
ymax = LinRange(1, -0.42, N)

display(fig)
for i = 1:50
    _x = LinRange(xmin[i], xmax[i], 200)
    _y = LinRange(ymin[i], ymax[i], 200)
    hm[1] = _x 
    hm[2] = _y 
    hm[3] = mandelbrot.(_x, _y')
    autolimits!(ax) 
    yield() 
end