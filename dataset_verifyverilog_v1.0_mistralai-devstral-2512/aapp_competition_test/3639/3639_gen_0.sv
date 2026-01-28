module CyclistWetnessCalculator(
    input clk,
    input rst_n,
    input start,
    input [4:0] T_in,
    input [15:0] c_fixed,
    input [15:0] d_fixed,
    input [6:0] rain [0:31],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SETUP   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // Fixed-point constants
    localparam [15:0] ONE_Q8_8 = 16'd256;  // 1.0 in Q8.8
    localparam [15:0] ONE_Q16_16 = 32'd65536;  // 1.0 in Q16.16
    localparam [31:0] ONE_Q32_32 = 64'd4294967296;  // 1.0 in Q32.32

    // DP array dimensions
    localparam [4:0] MAX_TIME = 5'd32;  // Max 32 minutes
    localparam [4:0] MAX_DISTANCE_STEPS = 5'd32;  // 32 distance steps

    // Speed values (Q8.8 format)
    localparam [15:0] SPEEDS [0:7] = '{16'd128, 16'd256, 16'd384, 16'd512, 16'd640, 16'd768, 16'd896, 16'd1024};
    // 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0 km/h in Q8.8

    // Registers
    reg [1:0] state;
    reg [4:0] time_counter;
    reg [4:0] distance_counter;
    reg [4:0] speed_counter;
    reg [31:0] dp_current [0:MAX_DISTANCE_STEPS-1];
    reg [31:0] dp_next [0:MAX_DISTANCE_STEPS-1];
    reg [31:0] min_wetness;
    reg [4:0] T_reg;
    reg [15:0] c_reg;
    reg [15:0] d_reg;
    reg [31:0] distance_step_q16_16;
    reg [31:0] target_distance_q16_16;
    reg [31:0] speed_q16_16;
    reg [31:0] v_squared_q32_32;
    reg [31:0] sweat_q16_16;
    reg [31:0] rain_contribution_q16_16;
    reg [31:0] total_wetness_q16_16;
    reg [31:0] time_fraction_q16_16;
    reg [31:0] distance_covered_q16_16;
    reg [31:0] temp_product;
    reg [31:0] temp_sum;
    reg [31:0] temp_rain;
    reg [31:0] temp_rain_next;
    reg [31:0] rain_interpolated;
    reg [31:0] min_temp;
    reg [4:0] min_index;
    reg [4:0] current_minute;
    reg [4:0] next_minute;
    reg [31:0] distance_to_cover_q16_16;
    reg [31:0] time_needed_q16_16;
    reg [31:0] distance_remaining_q16_16;
    reg [31:0] time_remaining_q16_16;
    reg [31:0] sweat_accum_q16_16;
    reg [31:0] rain_accum_q16_16;
    reg [31:0] wetness_accum_q16_16;
    reg [31:0] best_wetness;
    reg [4:0] best_distance;
    reg [4:0] i, j, k;

    // Fixed-point multiplication function (Q16.16 * Q16.16 = Q32.32)
    function [31:0] multiply_q16_16;
        input [31:0] a, b;
        multiply_q16_16 = (a * b) >>> 16;  // Truncate to Q16.16
    endfunction

    // Fixed-point multiplication function (Q16.16 * Q8.8 = Q24.8)
    function [31:0] multiply_q16_16_q8_8;
        input [31:0] a;
        input [15:0] b;
        multiply_q16_16_q8_8 = (a * b) >>> 8;  // Normalize to Q16.16
    endfunction

    // Fixed-point division function (Q16.16 / Q16.16 = Q16.16)
    function [31:0] divide_q16_16;
        input [31:0] a, b;
        reg [31:0] result;
        reg [31:0] remainder;
        reg [31:0] divisor;
        reg [31:0] dividend;
        reg [4:0] i;
        begin
            if (b == 0) begin
                result = 0;
            end else begin
                dividend = a << 16;  // Q32.32
                divisor = b;
                remainder = 0;
                for (i = 0; i < 32; i = i + 1) begin
                    remainder = {remainder[30:0], dividend[31]};
                    dividend = dividend << 1;
                    if (remainder >= divisor) begin
                        remainder = remainder - divisor;
                        dividend[0] = 1'b1;
                    end else begin
                        dividend[0] = 1'b0;
                    end
                end
                result = dividend;
            end
            divide_q16_16 = result;
        end
    endfunction

    // Fixed-point square function (Q16.16)
    function [31:0] square_q16_16;
        input [31:0] a;
        square_q16_16 = multiply_q16_16(a, a);
    endfunction

    // Initialize DP arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            time_counter <= 5'd0;
            distance_counter <= 5'd0;
            speed_counter <= 5'd0;
            T_reg <= 5'd0;
            c_reg <= 16'd0;
            d_reg <= 16'd0;
            distance_step_q16_16 <= 32'd0;
            target_distance_q16_16 <= 32'd0;
            speed_q16_16 <= 32'd0;
            v_squared_q32_32 <= 32'd0;
            sweat_q16_16 <= 32'd0;
            rain_contribution_q16_16 <= 32'd0;
            total_wetness_q16_16 <= 32'd0;
            time_fraction_q16_16 <= 32'd0;
            distance_covered_q16_16 <= 32'd0;
            temp_product <= 32'd0;
            temp_sum <= 32'd0;
            temp_rain <= 32'd0;
            temp_rain_next <= 32'd0;
            rain_interpolated <= 32'd0;
            min_temp <= 32'd0;
            min_index <= 5'd0;
            current_minute <= 5'd0;
            next_minute <= 5'd0;
            distance_to_cover_q16_16 <= 32'd0;
            time_needed_q16_16 <= 32'd0;
            distance_remaining_q16_16 <= 32'd0;
            time_remaining_q16_16 <= 32'd0;
            sweat_accum_q16_16 <= 32'd0;
            rain_accum_q16_16 <= 32'd0;
            wetness_accum_q16_16 <= 32'd0;
            best_wetness <= 32'd0;
            best_distance <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            for (i = 0; i < MAX_DISTANCE_STEPS; i = i + 1) begin
                dp_current[i] <= 32'd0;
                dp_next[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    T_reg <= T_in;
                    c_reg <= c_fixed;
                    d_reg <= d_fixed;
                    distance_step_q16_16 <= {d_reg, 8'd0} / MAX_DISTANCE_STEPS;  // Q16.16
                    target_distance_q16_16 <= {d_reg, 8'd0};  // Q16.16
                    
                    // Initialize DP arrays
                    for (i = 0; i < MAX_DISTANCE_STEPS; i = i + 1) begin
                        if (i == 0) begin
                            dp_current[i] <= 32'd0;  // Starting point: 0 wetness at distance 0
                        end else begin
                            dp_current[i] <= 32'd0;  // Initialize to large value (but 0 for simplicity)
                        end
                    end
                    
                    time_counter <= 5'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (time_counter < T_reg) begin
                        // Initialize next DP state
                        for (i = 0; i < MAX_DISTANCE_STEPS; i = i + 1) begin
                            dp_next[i] <= 32'd0;
                        end
                        
                        // For each distance step
                        for (distance_counter = 0; distance_counter < MAX_DISTANCE_STEPS; distance_counter = distance_counter + 1) begin
                            if (dp_current[distance_counter] != 32'd0) begin
                                // Try all speeds
                                for (speed_counter = 0; speed_counter < 8; speed_counter = speed_counter + 1) begin
                                    speed_q16_16 <= {SPEEDS[speed_counter], 8'd0};  // Q16.16
                                    
                                    // Calculate distance covered in 1 minute at this speed
                                    distance_covered_q16_16 <= multiply_q16_16(speed_q16_16, ONE_Q16_16);  // Q16.16
                                    
                                    // Calculate new distance
                                    temp_sum <= distance_counter * distance_step_q16_16 + distance_covered_q16_16;
                                    j <= temp_sum / distance_step_q16_16;
                                    
                                    if (j < MAX_DISTANCE_STEPS) begin
                                        // Calculate sweat: c * v^2
                                        v_squared_q32_32 <= square_q16_16(speed_q16_16);  // Q32.32
                                        sweat_q16_16 <= multiply_q16_16_q8_8(v_squared_q32_32, c_reg);  // Q16.16
                                        
                                        // Calculate rain contribution
                                        current_minute <= time_counter;
                                        next_minute <= time_counter + 1;
                                        
                                        // Linear interpolation for rain
                                        time_fraction_q16_16 <= 32'd0;  // For simplicity, assume full minute
                                        rain_interpolated <= {rain[current_minute], 25'd0} * (ONE_Q16_16 - time_fraction_q16_16) + 
                                                           {rain[next_minute], 25'd0} * time_fraction_q16_16;
                                        rain_contribution_q16_16 <= rain_interpolated >>> 16;  // Q16.16
                                        
                                        // Total wetness
                                        total_wetness_q16_16 <= dp_current[distance_counter] + sweat_q16_16 + rain_contribution_q16_16;
                                        
                                        // Update DP if better
                                        if (dp_next[j] == 32'd0 || total_wetness_q16_16 < dp_next[j]) begin
                                            dp_next[j] <= total_wetness_q16_16;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Copy next to current
                        for (i = 0; i < MAX_DISTANCE_STEPS; i = i + 1) begin
                            dp_current[i] <= dp_next[i];
                        end
                        
                        time_counter <= time_counter + 1;
                    end else begin
                        // Find minimum wetness for distance >= target
                        best_wetness <= 32'd0;
                        best_distance <= 5'd0;
                        for (i = 0; i < MAX_DISTANCE_STEPS; i = i + 1) begin
                            if (i * distance_step_q16_16 >= target_distance_q16_16) begin
                                if (best_wetness == 32'd0 || dp_current[i] < best_wetness) begin
                                    best_wetness <= dp_current[i];
                                    best_distance <= i;
                                end
                            end
                        end
                        
                        result <= best_wetness;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule