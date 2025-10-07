using GLMakie
using Colors

# Mandelbrot computation function
function mandelbrot_point(c::Complex{Float64}, max_iter::Int=100)
    z = 0.0 + 0.0im
    for i in 1:max_iter
        if abs2(z) > 4.0
            return i
        end
        z = z^2 + c
    end
    return max_iter
end

# Vectorized Mandelbrot computation
function compute_mandelbrot(x_range, y_range, width::Int, height::Int, max_iter::Int=100)
    result = Matrix{Int}(undef, height, width)
    
    x_step = (x_range[2] - x_range[1]) / (width - 1)
    y_step = (y_range[2] - y_range[1]) / (height - 1)
    
    Threads.@threads for j in 1:height
        y = y_range[1] + (j - 1) * y_step
        for i in 1:width
            x = x_range[1] + (i - 1) * x_step
            c = complex(x, y)
            result[j, i] = mandelbrot_point(c, max_iter)
        end
    end
    
    return result
end

# Convert pixel coordinates to complex plane coordinates
function pixel_to_complex(pixel_x, pixel_y, x_range, y_range, width, height)
    x = x_range[1] + (pixel_x - 1) * (x_range[2] - x_range[1]) / (width - 1)
    y = y_range[1] + (pixel_y - 1) * (y_range[2] - y_range[1]) / (height - 1)
    return complex(x, y)
end

function main()
    # Initial parameters
    width, height = 800, 600
    max_iter = 100
    zoom_factor = 0.98  # How fast to zoom (closer to 1 = slower)
    
    # Initial view of Mandelbrot set
    x_range = [-2.5, 1.5]
    y_range = [-1.5, 1.5]
    
    # Compute initial Mandelbrot set
    mandelbrot_data = compute_mandelbrot(x_range, y_range, width, height, max_iter)
    
    # Create figure and axis
    fig = Figure(resolution=(width, height))
    ax = Axis(fig[1, 1], aspect=DataAspect())
    hidedecorations!(ax)
    
    # Create heatmap
    hm = heatmap!(ax, mandelbrot_data, colormap=:hot, interpolate=true)
    hm_obs = Observable(hm)
    
    # Variables to track mouse position
    mouse_x = Ref(width ÷ 2)
    mouse_y = Ref(height ÷ 2)
    current_x_range = Ref(x_range)
    current_y_range = Ref(y_range)
    
    # Mouse position tracking
    on(events(fig).mouseposition) do pos
        # Convert screen coordinates to pixel coordinates
        mouse_x[] = clamp(round(Int, pos[1]), 1, width)
        mouse_y[] = clamp(round(Int, height - pos[2]), 1, height)  # Flip Y coordinate
    end
    
    # Animation loop
    fps = 30
    frame_time = 1.0 / fps
    
    # Timer for continuous updates
    timer = Timer(0.0, interval=frame_time) do t
        # Get current mouse position in complex coordinates
        target = pixel_to_complex(mouse_x[], mouse_y[], 
                                current_x_range[], current_y_range[], 
                                width, height)
        
        # Calculate new zoom window centered on mouse position
        current_width = current_x_range[][2] - current_x_range[][1]
        current_height = current_y_range[][2] - current_y_range[][1]
        
        new_width = current_width * zoom_factor
        new_height = current_height * zoom_factor
        
        # Center the new window on the mouse target
        new_x_range = [real(target) - new_width/2, real(target) + new_width/2]
        new_y_range = [imag(target) - new_height/2, imag(target) + new_height/2]
        
        current_x_range[] = new_x_range
        current_y_range[] = new_y_range
        
        # Adjust max_iter based on zoom level for better detail
        scale = min(current_width, current_height)
        adaptive_max_iter = max(50, min(500, round(Int, 100 / scale^0.3)))
        
        # Compute new Mandelbrot data
        new_data = compute_mandelbrot(new_x_range, new_y_range, width, height, adaptive_max_iter)
        
        # Update heatmap
        #print(hm)
        #hm[3] = new_data
        heatmap!(hm, new_data)
        
        # Force refresh
        notify(hm_obs)
    end
    
    # Display the figure
    display(fig)
    
    # Instructions
    # Keep the program running
    try
        while isopen(fig.scene)
            sleep(0.1)
        end
    finally
        close(timer)
    end
end

# Run the program
main()