using GLMakie

struct window{T<:Real}
    x_min::T
    x_max::T
    y_min::T
    y_max::T
    x_resolution::Int
    y_resolution::Int
end

function pixel(c::Complex{Float64}, max_iter::Int=100)
    z =  0.0 + 0.0im
    for i in 1:max_iter
        if abs2(z) > 4.0
            return i
        end
        z = z ^ 2 + c
    end
    return max_iter
end

function frame(sizes::window, max_iter::Int=100)
    result = Matrix{Int}(undef, sizes.y_resolution, sizes.x_resolution)

    x_step = (sizes.x_max - sizes.x_min) / (sizes.x_resolution - 1)
    y_step = (sizes.y_max - sizes.y_min) / (sizes.y_resolution - 1)

    for i in 1:sizes.y_resolution
        y = sizes.y_min + (i - 1) * y_step
        for j in 1:sizes.x_resolution
            x = sizes.x_min + (j - 1) * x_step
            c = complex(x, y)
            result[i, j] = pixel(c, max_iter)
        end
    end
    return result
end

function frame!(sizes::window, result::Matrix{Int}, max_iter::Int=100)
    #result = Matrix{Int}(undef, sizes.y_resolution, sizes.x_resolution)

    x_step = (sizes.x_max - sizes.x_min) / (sizes.x_resolution - 1)
    y_step = (sizes.y_max - sizes.y_min) / (sizes.y_resolution - 1)

    Threads.@threads for i in 1:sizes.y_resolution
        y = sizes.y_min + (i - 1) * y_step
        for j in 1:sizes.x_resolution
            x = sizes.x_min + (j - 1) * x_step
            c = complex(x, y)
            result[i, j] = pixel(c, max_iter)
        end
    end
end

function pixel_to_complex(x::Real, y::Real, sizes::window)
    c_x = sizes.x_min + (x - 1) * (sizes.x_max - sizes.x_min) / (sizes.x_resolution)
    c_y = sizes.y_min + (y - 1) * (sizes.y_max - sizes.y_min) / (sizes.y_resolution)

    return complex(c_x, c_y)
end

function zoom(size::window, (y_mousepos, x_mousepos), rate::Real = 0.99, sensitivity::Real = 0.1)
    width = size.x_max - size.x_min
    height = size.y_max - size.y_min

    x_radius = (x_mousepos - (size.x_resolution / 2)) * sensitivity
    y_radius = (y_mousepos - (size.y_resolution / 2)) * sensitivity
    
    x_mouse = size.x_min + (x_radius + size.x_resolution/2)/size.x_resolution * width
    y_mouse = size.y_min + (y_radius + size.y_resolution/2)/size.y_resolution * height
    
    new_width = rate * width
    new_height = rate * height

    new_x_min = x_mouse - (new_width / 2)
    new_x_max = x_mouse + (new_width / 2)
    new_y_min = y_mouse - (new_height / 2)
    new_y_max = y_mouse + (new_height / 2)

    return window(new_x_min, new_x_max, new_y_min, new_y_max, size.x_resolution, size.y_resolution)
end

function main()
    GLMakie.activate!()
    window_param = window(-2.5, 1.5, -1.5, 1.5, 1000, 1000)
    init_frame = frame(window_param)

    current_frame = Observable(init_frame)
    scene = Scene(camera = campixel!, size=(window_param.x_resolution, window_param.x_resolution))

    heatmap!(scene, current_frame[])
    #fig, ax, hm = heatmap!(scene, current_frame[])
    on(current_frame) do current_frame
        heatmap!(scene, current_frame)
    end
    
    display(scene)

    sleep(5)
    for _ in 1:1000
	if !isopen(scene)
		return nothing
	end
        mp = events(scene).mouseposition[]
        window_param = zoom(window_param, mp)
	frame!(window_param, current_frame[])
	heatmap!(scene, current_frame)
        sleep(0.01)
    end
    return nothing
end


