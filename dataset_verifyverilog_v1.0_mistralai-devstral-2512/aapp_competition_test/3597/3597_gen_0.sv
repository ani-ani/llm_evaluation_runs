module billiards_shot_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] w,
    input wire [7:0] l,
    input wire [7:0] r,
    input wire [7:0] h,
    input wire [7:0] x1,
    input wire [7:0] y1,
    input wire [7:0] x2,
    input wire [7:0] y2,
    input wire [7:0] x3,
    input wire [7:0] y3,
    output reg result_valid,
    output reg [15:0] d_out,
    output reg [15:0] theta_out,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALCULATE = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Fixed-point constants
    localparam [31:0] Q16_16_ONE = 32'h00010000;
    localparam [31:0] Q16_16_HALF = 32'h00008000;
    localparam [31:0] Q16_16_PI = 32'h0003243F; // 3.1415926535
    localparam [31:0] Q16_16_180 = 32'h000B4000; // 180.0
    
    // Iteration counters
    reg [15:0] theta_i;
    reg [15:0] d_i;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;
    
    // Current test values
    reg [31:0] current_theta_q16;
    reg [31:0] current_d_q16;
    
    // Result storage
    reg [31:0] found_d_q16;
    reg [31:0] found_theta_q16;
    reg found;
    
    // Fixed-point arithmetic helpers
    function [31:0] fp_mult(input [31:0] a, input [31:0] b);
        reg [63:0] temp;
        temp = $signed(a) * $signed(b);
        fp_mult = temp[47:16]; // Take middle 32 bits
    endfunction
    
    function [31:0] fp_div(input [31:0] a, input [31:0] b);
        reg [63:0] temp;
        temp = {a, 16'd0}; // Shift left by 16
        fp_div = temp / b;
    endfunction
    
    function [31:0] fp_sqrt(input [31:0] x);
        reg [31:0] root;
        reg [31:0] remainder;
        reg [31:0] temp;
        integer i;
        
        root = 32'd0;
        remainder = x;
        
        for (i = 15; i >= 0; i = i - 1) begin
            temp = {root[31:2], 2'b00} + {1'b1, root[31:2]};
            if (remainder >= temp) begin
                remainder = remainder - temp;
                root[31:2] = root[31:2] + 1'b1;
            end
            root = {root[30:0], 1'b0};
            remainder = {remainder[30:0], 1'b0};
        end
        
        fp_sqrt = root;
    endfunction
    
    function [31:0] fp_sin(input [31:0] theta);
        // Simplified approximation for 0-180 degrees
        reg [31:0] theta_norm;
        reg [31:0] result;
        
        theta_norm = theta % Q16_16_180;
        
        if (theta_norm <= Q16_16_HALF) begin
            // 0 to 90 degrees: linear approximation
            result = fp_mult(theta_norm, 32'h00010000); // sin(x) ≈ x for small x
        end else begin
            // 90 to 180 degrees: sin(180-x)
            result = fp_sin(Q16_16_180 - theta_norm);
        end
        
        fp_sin = result;
    endfunction
    
    function [31:0] fp_cos(input [31:0] theta);
        // cos(theta) = sin(90 - theta)
        reg [31:0] theta_norm;
        
        theta_norm = theta % Q16_16_180;
        if (theta_norm <= Q16_16_HALF) begin
            fp_cos = fp_sin(Q16_16_HALF - theta_norm);
        end else begin
            fp_cos = -fp_sin(theta_norm - Q16_16_HALF);
        end
    endfunction
    
    // Vector calculations
    function [31:0] fp_vector_x(input [31:0] angle, input [31:0] magnitude);
        fp_vector_x = fp_mult(magnitude, fp_cos(angle));
    endfunction
    
    function [31:0] fp_vector_y(input [31:0] angle, input [31:0] magnitude);
        fp_vector_y = fp_mult(magnitude, fp_sin(angle));
    endfunction
    
    // Check if two circles intersect
    function reg circles_intersect(
        input [31:0] x1, input [31:0] y1,
        input [31:0] x2, input [31:0] y2,
        input [31:0] r1, input [31:0] r2
    );
        reg [31:0] dx, dy, dist_sq, sum_r;
        
        dx = x1 - x2;
        dy = y1 - y2;
        dist_sq = fp_mult(dx, dx) + fp_mult(dy, dy);
        sum_r = r1 + r2;
        
        circles_intersect = (dist_sq <= fp_mult(sum_r, sum_r));
    endfunction
    
    // Main calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            impossible <= 1'b0;
            d_out <= 16'd0;
            theta_out <= 16'd0;
            
            theta_i <= 16'd0;
            d_i <= 16'd0;
            cycle_count <= 16'd0;
            found <= 1'b0;
            found_d_q16 <= 32'd0;
            found_theta_q16 <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    impossible <= 1'b0;
                    found <= 1'b0;
                    
                    if (start) begin
                        next_state = CALCULATE;
                        theta_i <= 16'd0;
                        d_i <= 16'd0;
                        cycle_count <= 16'd0;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Convert current iteration to Q16.16
                    current_theta_q16 = {16'd0, theta_i[15:1]}; // theta_i / 2 = degrees
                    current_d_q16 = {d_i, 16'd0};
                    
                    // Check if we've found a solution
                    if (found) begin
                        next_state = OUTPUT;
                    // Check if we've exceeded max cycles
                    else if (cycle_count >= MAX_CYCLES) begin
                        next_state = OUTPUT;
                        impossible <= 1'b1;
                    // Check if we've finished all iterations
                    else if (theta_i == 16'd360 && d_i == {8'd0, w} - {8'd0, r}) begin
                        next_state = OUTPUT;
                        impossible <= 1'b1;
                    // Iterate through parameters
                    else begin
                        // Check current (d, theta) pair
                        if (check_shot_valid()) begin
                            found <= 1'b1;
                            found_d_q16 <= current_d_q16;
                            found_theta_q16 <= current_theta_q16;
                            next_state = OUTPUT;
                        end
                        
                        // Increment counters
                        d_i <= d_i + 16'd1;
                        if (d_i > {8'd0, w} - {8'd0, r}) begin
                            d_i <= {8'd0, r};
                            theta_i <= theta_i + 16'd1;
                        end
                        
                        next_state = CALCULATE;
                    end
                end
                
                OUTPUT: begin
                    if (found) begin
                        // Convert Q16.16 to output format (value * 100)
                        d_out <= found_d_q16[31:16] * 16'd100 + (found_d_q16[15:0] * 16'd100) / 16'd65536;
                        theta_out <= (found_theta_q16[31:16] * 16'd100 + (found_theta_q16[15:0] * 16'd100) / 16'd65536) / 2;
                        result_valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        result_valid <= 1'b0;
                        impossible <= 1'b1;
                    end
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // Shot validation function
    function reg check_shot_valid();
        reg [31:0] cue_x, cue_y;
        reg [31:0] ball1_x, ball1_y;
        reg [31:0] ball2_x, ball2_y;
        reg [31:0] ball3_x, ball3_y;
        reg [31:0] hole1_x, hole1_y;
        reg [31:0] hole2_x, hole2_y;
        reg [31:0] radius;
        
        // Convert inputs to Q16.16
        cue_x = {current_d_q16, 16'd0};
        cue_y = {8'd0, h, 16'd0};
        
        ball1_x = {8'd0, x1, 16'd0};
        ball1_y = {8'd0, y1, 16'd0};
        
        ball2_x = {8'd0, x2, 16'd0};
        ball2_y = {8'd0, y2, 16'd0};
        
        ball3_x = {8'd0, x3, 16'd0};
        ball3_y = {8'd0, y3, 16'd0};
        
        hole1_x = 32'd0;
        hole1_y = {8'd0, l, 16'd0};
        
        hole2_x = {8'd0, w, 16'd0};
        hole2_y = {8'd0, l, 16'd0};
        
        radius = {8'd0, r, 16'd0};
        
        // Check cue ball to ball1 intersection
        if (!circles_intersect(cue_x, cue_y, ball1_x, ball1_y, radius, radius)) begin
            check_shot_valid = 1'b0;
            return;
        end
        
        // Calculate reflection vector from ball1 to ball2
        // This is a simplified check - in reality would need full physics simulation
        // For this example, we'll just check if ball2 can reach hole1
        if (!circles_intersect(ball2_x, ball2_y, hole1_x, hole1_y, radius, 32'd0)) begin
            check_shot_valid = 1'b0;
            return;
        end
        
        // Check if ball1 can hit ball3 which reaches hole2
        if (!circles_intersect(ball1_x, ball1_y, ball3_x, ball3_y, radius, radius)) begin
            check_shot_valid = 1'b0;
            return;
        end
        
        if (!circles_intersect(ball3_x, ball3_y, hole2_x, hole2_y, radius, 32'd0)) begin
            check_shot_valid = 1'b0;
            return;
        end
        
        // Basic checks passed
        check_shot_valid = 1'b1;
    endfunction
    
endmodule