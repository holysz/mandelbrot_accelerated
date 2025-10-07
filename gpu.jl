using Images, Colors, ColorSchemes
using CuArrays, GPUArrays

# get the number of steps
function get_steps(c::Complex, max_steps)
    z = Complex(0.0, 0.0) # 0 + 0im
    for i=1:max_steps
        z = z*z+c
        if abs2(z) >= 4
            return i
        end
    end
    return max_steps+1
end

function get_color(colorscheme, step, max_steps)
    if step == max_steps+1
        return [0.0, 0.0, 0.0]
    end
    color = get(colorscheme, step, (1, max_steps))
    return [color.r, color.g, color.b]
end

function get_cmap(colorscheme, max_steps)
    colors = zeros(Float64, (3, max_steps+1))
    for i=1:max_steps 
        colors[:,i] = get_color(colorscheme, i, max_steps)
    end
    colors[:,max_steps+1] = [0.0, 0.0, 0.0]
    return colors
end

function mandelbrot_plot()
    width = 1000
    height = 600

    max_steps = 3500
    steps = zeros(Int, (height, width))
   
    # range for real values
    cr_min = -0.7491597623
    cr_max = -0.7491597623+0.0000000004

    # range for imaginary values
    ci_min = 0.1005089256
    
    range = cr_max - cr_min
    dot_size = range/width
    ci_max = ci_min + height*dot_size

    # println("cr: $cr_min - $cr_max")
    # println("ci: $ci_min - $ci_max")

    image = zeros(Float64, (3, height, width))
    complexes = zeros(ComplexF64, (height, width))
    steps = zeros(Int, (height, width))
    cu_steps = CuArray(zeros(Int, (height, width)))

    colorscheme = ColorSchemes.inferno
    colorscheme_sized = get_cmap(colorscheme, max_steps)
    x, y = 1,1
    for ci=ci_min:dot_size:ci_max-dot_size
        x = 1
        for cr=cr_min:dot_size:cr_max-dot_size
            complexes[y,x] = Complex(cr, ci)
            x += 1
        end
        y += 1
    end
    cu_complexes = CuArray(complexes)
    cu_steps .= get_steps.(cu_complexes, max_steps)
    GPUArrays.synchronize(cu_steps)
    steps = Array(cu_steps)
    
    image = colorscheme_sized[:, steps]
    
    save("images/test.bmp", colorview(RGB, image))
end

@time mandelbrot_plot();