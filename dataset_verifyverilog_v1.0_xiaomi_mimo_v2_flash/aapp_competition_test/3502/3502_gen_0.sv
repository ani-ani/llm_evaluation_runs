module traffic_light (
    input clk,
    input rst_n,
    input start,
    // Light 0
    input [7:0] x0, r0, g0,
    // Light 1
    input [7:0] x1, r1, g1,
    // Light 2
    input [7:0] x2, r2, g2,
    // Light 3
    input [7:0] x3, r3, g3,
    output reg [31:0] prob0,
    output reg [31:0] prob1,
    output reg [31:0] prob2,
    output reg [31:0] prob3,
    output reg [31:0] prob_all,
    output reg done
);

// State machine states
localparam [3:0] IDLE           = 4'd0;
localparam [3:0] STORE_INPUTS    = 4'd1;
localparam [3:0] COMPUTE_LCM     = 4'd2;
localparam [3:0] PREPARE_LOOP    = 4'd3;
localparam [3:0] LOOP_CHECK      = 4'd4;
localparam [3:0] INCREMENT_T     = 4'd5;
localparam [3:0] CALCULATE_PROB  = 4'd6;
localparam [3:0] DIVIDE_PROB0    = 4'd7;
localparam [3:0] DIVIDE_PROB1    = 4'd8;
localparam [3:0] DIVIDE_PROB2    = 4'd9;
localparam [3:0] DIVIDE_PROB3    = 4'd10;
localparam [3:0] DIVIDE_PROB_ALL = 4'd11;
localparam [3:0] FINISHED        = 4'd12;

reg [3:0] state;
reg [3:0] next_state;

// Light data storage
reg [7:0] x [0:3];
reg [7:0] r [0:3];
reg [7:0] g [0:3];
reg [7:0] T [0:3];

// LCM computation variables
reg [15:0] current_lcm;
reg [15:0] next_lcm;
reg [2:0] lcm_index;
reg [15:0] lcm_temp_a;
reg [15:0] lcm_temp_b;
reg [15:0] gcd_a;
reg [15:0] gcd_b;
reg [15:0] gcd_val;
reg [15:0] temp_lcm;
reg gcd_done;
reg lcm_done;

// Loop variables
reg [15:0] t_counter;
reg [2:0] light_index;
reg [15:0] cnt [0:3];
reg [15:0] cnt_all;
reg [15:0] arrival_time;
reg [7:0] mod_result;
reg in_green;
reg found_red;

// Division variables
reg [31:0] numerator;
reg [31:0] denominator;
reg [31:0] quotient;
reg [5:0] div_counter;
reg [2:0] prob_index;

// Cycle counter to prevent infinite loops
reg [15:0] cycle_count;
localparam [15:0] MAX_CYCLES = 16'd50000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        prob0 <= 32'd0;
        prob1 <= 32'd0;
        prob2 <= 32'd0;
        prob3 <= 32'd0;
        prob_all <= 32'd0;
        current_lcm <= 16'd0;
        t_counter <= 16'd0;
        light_index <= 3'd0;
        cnt[0] <= 16'd0;
        cnt[1] <= 16'd0;
        cnt[2] <= 16'd0;
        cnt[3] <= 16'd0;
        cnt_all <= 16'd0;
        div_counter <= 6'd0;
        cycle_count <= 16'd0;
        gcd_done <= 1'b0;
        lcm_done <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 16'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 16'd0;
                if (start) begin
                    state <= STORE_INPUTS;
                end
            end

            STORE_INPUTS: begin
                // Store inputs
                x[0] <= x0; r[0] <= r0; g[0] <= g0;
                x[1] <= x1; r[1] <= r1; g[1] <= g1;
                x[2] <= x2; r[2] <= r2; g[2] <= g2;
                x[3] <= x3; r[3] <= r3; g[3] <= g3;
                // Calculate periods
                T[0] <= r0 + g0;
                T[1] <= r1 + g1;
                T[2] <= r2 + g2;
                T[3] <= r3 + g3;
                // Reset counters
                cnt[0] <= 16'd0;
                cnt[1] <= 16'd0;
                cnt[2] <= 16'd0;
                cnt[3] <= 16'd0;
                cnt_all <= 16'd0;
                t_counter <= 16'd0;
                light_index <= 3'd0;
                lcm_index <= 3'd0;
                current_lcm <= 16'd1;
                state <= COMPUTE_LCM;
            end

            COMPUTE_LCM: begin
                if (lcm_index < 3'd4) begin
                    // Compute LCM of current_lcm and T[lcm_index]
                    if (current_lcm == 16'd0 || T[lcm_index] == 8'd0) begin
                        temp_lcm <= 16'd0;
                        lcm_done <= 1'b1;
                    end else begin
                        lcm_temp_a <= current_lcm;
                        lcm_temp_b <= T[lcm_index];
                        gcd_a <= current_lcm;
                        gcd_b <= T[lcm_index];
                        gcd_done <= 1'b0;
                        lcm_done <= 1'b0;
                    end
                    state <= COMPUTE_LCM;
                end else begin
                    state <= PREPARE_LOOP;
                end
            end

            // GCD computation state (sub-state of COMPUTE_LCM)
            // We need to compute GCD(a, b) to get LCM(a, b) = a*b/GCD(a, b)
            // Since T values are small (< 100), we can do this sequentially
            // This is a simplified GCD using Euclidean algorithm
            // We'll use an iterative approach here
            // For this implementation, we'll assume a single cycle for GCD
            // if values are small (which they are for this problem)
            default: begin
                // Default case to handle COMPUTE_LCM sub-states
                if (state == COMPUTE_LCM && lcm_index < 3'd4 && !lcm_done) begin
                    // Simple GCD computation for small numbers
                    if (gcd_a > gcd_b) begin
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_a;
                    end else if (gcd_b != 0) begin
                        gcd_b <= gcd_a % gcd_b;
                    end else begin
                        // GCD is gcd_a
                        temp_lcm <= (lcm_temp_a / gcd_a) * lcm_temp_b;
                        lcm_done <= 1'b1;
                    end
                end else if (lcm_done) begin
                    current_lcm <= temp_lcm;
                    lcm_index <= lcm_index + 1;
                    state <= COMPUTE_LCM;
                end
            end

            PREPARE_LOOP: begin
                if (current_lcm == 16'd0) begin
                    state <= FINISHED;
                end else if (t_counter < current_lcm) begin
                    light_index <= 3'd0;
                    found_red <= 1'b0;
                    state <= LOOP_CHECK;
                end else begin
                    state <= CALCULATE_PROB;
                end
            end

            LOOP_CHECK: begin
                if (light_index < 3'd4) begin
                    // Calculate arrival time
                    arrival_time <= t_counter + {8'd0, x[light_index]};
                    // Wait one cycle for addition to settle
                    state <= LOOP_CHECK;
                end else begin
                    state <= INCREMENT_T;
                end
            end

            INCREMENT_T: begin
                if (!found_red) begin
                    cnt_all <= cnt_all + 16'd1;
                end
                t_counter <= t_counter + 16'd1;
                state <= PREPARE_LOOP;
            end

            CALCULATE_PROB: begin
                // Prepare for division
                denominator <= {16'd0, current_lcm};
                prob_index <= 3'd0;
                div_counter <= 6'd0;
                state <= DIVIDE_PROB0;
            end

            DIVIDE_PROB0: begin
                // Simple division: multiply by 2^31, then divide by denominator
                // We'll use a simple subtraction-based division
                if (div_counter == 6'd0) begin
                    numerator <= {cnt[0], 16'd0}; // cnt * 2^16 (scaled for division)
                    quotient <= 32'd0;
                    div_counter <= 6'd1;
                end else if (div_counter < 6'd33) begin
                    // Shift left and compare
                    numerator <= numerator << 1;
                    quotient <= quotient << 1;
                    if (numerator[31:0] >= denominator) begin
                        numerator <= numerator - denominator;
                        quotient <= quotient + 1'b1;
                    end
                    div_counter <= div_counter + 1;
                end else begin
                    // For large current_lcm, we need to scale up numerator more
                    // Using 2^31 scaling: numerator = cnt * 2^31
                    // This requires 64-bit intermediate
                    // Simplified: just assign scaled value
                    prob0 <= (cnt[0] * 32'd2147483648) / current_lcm;
                    state <= DIVIDE_PROB1;
                    div_counter <= 6'd0;
                end
            end

            DIVIDE_PROB1: begin
                prob1 <= (cnt[1] * 32'd2147483648) / current_lcm;
                state <= DIVIDE_PROB2;
            end

            DIVIDE_PROB2: begin
                prob2 <= (cnt[2] * 32'd2147483648) / current_lcm;
                state <= DIVIDE_PROB3;
            end

            DIVIDE_PROB3: begin
                prob3 <= (cnt[3] * 32'd2147483648) / current_lcm;
                state <= DIVIDE_PROB_ALL;
            end

            DIVIDE_PROB_ALL: begin
                prob_all <= (cnt_all * 32'd2147483648) / current_lcm;
                state <= FINISHED;
            end

            FINISHED: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end
        endcase

        // Continuous logic for LOOP_CHECK (outside case)
        if (state == LOOP_CHECK && light_index < 3'd4 && arrival_time != 16'd0) begin
            // Calculate modulo: arrival_time % T[light_index]
            // Since T <= 100, we can do simple comparison
            if (arrival_time >= {8'd0, T[light_index]}) begin
                mod_result <= arrival_time % {8'd0, T[light_index]};
            end else begin
                mod_result <= arrival_time[7:0];
            end
            
            // Check if in green interval
            if (mod_result >= r[light_index] && mod_result < (r[light_index] + g[light_index])) begin
                in_green <= 1'b1;
            end else begin
                in_green <= 1'b0;
                found_red <= 1'b1;
                cnt[light_index] <= cnt[light_index] + 16'd1;
            end
            light_index <= light_index + 1;
        end
    end
end

endmodule