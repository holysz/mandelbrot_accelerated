using GLMakie
using CUDA

mutable struct window{}
    x_min
    x_max
    y_min
    y_max
    x_resolution
    y_resolution
end

function pixel(c::Complex{Float32}, max_iter::Int=100)
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

    Threads.@threads for i in 1:sizes.y_resolution
        y = sizes.y_min + (i - 1) * y_step
        for j in 1:sizes.x_resolution
            x = sizes.x_min + (j - 1) * x_step
            c = complex(x, y)
            @inbounds result[i, j] = pixel(c, max_iter)
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
            @inbounds result[i, j] = pixel(c, max_iter)
        end
    end
end

function frame_kernel!(
    x_min::Float32,
	y_min::Float32,
    x_step::Float32,
    y_step::Float32,
	x_resolution::Int32,
	y_resolution::Int32,
	result::AbstractMatrix{Int32},
	max_iter::Int=100)

    i = (blockIdx().y - 1) * blockDim().y + threadIdx().y
    j = (blockIdx().x - 1) * blockDim().x + threadIdx().x

    if j <= x_resolution && i < y_resolution
        y = y_min + (i - 1) * y_step
        x = x_min + (j - 1) * x_step
        c = complex(x, y)

        @inbounds result[i, j] = pixel(c, max_iter)
   	end
    return nothing
end

function frame_wrapper!(sizes::window, result::AbstractMatrix{Int32}, max_iter::Int=100)
    x_step = (sizes.x_max - sizes.x_min) / (sizes.x_resolution - 1)
    y_step = (sizes.y_max - sizes.y_min) / (sizes.y_resolution - 1)

    @cuda threads=(16, 16) blocks=(240, 240) frame_kernel!( 
        sizes.x_min, sizes.y_min,
        x_step, y_step,
        sizes.x_resolution, sizes.y_resolution,
        result,
        max_iter
    )
    
    CUDA.synchronize()
end


function pixel_to_complex(x::Real, y::Real, sizes::window)
    c_x = sizes.x_min + (x - 1) * (sizes.x_max - sizes.x_min) / (sizes.x_resolution)
    c_y = sizes.y_min + (y - 1) * (sizes.y_max - sizes.y_min) / (sizes.y_resolution)

    return complex(c_x, c_y)
end

function zoom!(size::window, (y_mousepos, x_mousepos), rate::Float32 = 0.99f0, sensitivity::Float32 = 0.1f0)
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

    size.x_min = Float32(new_x_min)
    size.x_max = Float32(new_x_max)
    size.y_min = Float32(new_y_min)
    size.y_max = Float32(new_y_max)

    #return window(new_x_min, new_x_max, new_y_min, new_y_max, size.x_resolution, size.y_resolution)
end

function main()
    GLMakie.activate!()
    window_param = window(-1.125f0, 1.125f0, -2.5f0, 1.5f0, Int32(1080), Int32(1920))

    init_frame = CUDA.zeros(Int32, window_param.y_resolution, window_param.x_resolution)
    frame_wrapper!(window_param, init_frame)

    current_frame = Observable(init_frame)
    scene = Scene(camera = campixel!, size=(window_param.y_resolution, window_param.x_resolution))
    current_fps = Observable(0)

    print(size(current_frame[]))
    heatmap!(scene, Array(current_frame[]))
    
    display(scene)

    sleep(3)
    fps = 0
    start = time()
    for i in 1:5000
	fps += 1
	finish = time()
	if finish - start > 1
		current_fps[] = fps
		start = finish
		print(fps, "\n")
		fps = 0
	end
        if !isopen(scene)
            return nothing
        end
        mp = events(scene).mouseposition[]
	    zoom!(window_param, (Float32(mp[1]), Float32(mp[2])))
	    frame_wrapper!(window_param, current_frame[])
	    heatmap!(scene, Array(current_frame[]))
    	text!(scene, @lift("FPS: $($(current_fps))"),
	      position = (50, window_param.x_resolution - 50),  # Top-left corner with padding
	      color = :white,
	      fontsize = 24,
	      align = (:left, :top))
    end
    return nothing
end


