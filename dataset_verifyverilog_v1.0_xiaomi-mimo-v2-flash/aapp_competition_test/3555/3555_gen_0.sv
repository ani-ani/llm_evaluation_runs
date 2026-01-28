module spot_leash (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] data_in,
    input wire data_valid,
    input wire data_type,
    input wire [5:0] data_count,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] CALC    = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DIST    = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    // Registers and counters
    reg [2:0] state, next_state;
    reg [5:0] data_counter;      // Tracks loaded items
    reg [5:0] toy_counter;       // Tracks processed toys
    reg [3:0] tree_counter;      // 8 trees max
    reg [2:0] tree_depth;        // Actual number of trees loaded
    
    // Data storage
    reg signed [15:0] toys_x [0:15];   // 16 toys max
    reg signed [15:0] toys_y [0:15];
    reg signed [15:0] trees_x [0:7];   // 8 trees max
    reg signed [15:0] trees_y [0:7];
    
    // Position tracking
    reg signed [15:0] curr_x;
    reg signed [15:0] curr_y;
    
    // Accumulator (Q16.16)
    reg [31:0] total_length;
    
    // Calculation registers
    reg signed [15:0] dx;
    reg signed [15:0] dy;
    reg signed [15:0] abs_dx;
    reg signed [15:0] abs_dy;
    reg signed [31:0] cross_prod;
    reg [31:0] dist_sq;
    reg [31:0] dist_approx;      // Q16.16
    reg [31:0] dist_penalty;     // Q16.16
    reg [31:0] temp_mult;        // Q16.16
    reg obstacle_flag;
    
    // Counter for loops
    reg [3:0] loop_idx;
    
    // Cycle counter for timeout
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (data_counter >= data_count) next_state = CALC;
                else next_state = LOAD;
            end
            CALC: begin
                if (toy_counter >= data_count[5:0]) next_state = DONE;
                else next_state = CHECK;
            end
            CHECK: begin
                if (tree_counter >= tree_depth) next_state = DIST;
                else next_state = CHECK;
            end
            DIST: next_state = CALC;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            data_counter <= 6'd0;
            toy_counter <= 6'd0;
            tree_counter <= 4'd0;
            tree_depth <= 3'd0;
            curr_x <= 16'sd0;
            curr_y <= 16'sd0;
            total_length <= 32'd0;
            cycle_count <= 16'd0;
            // Initialize arrays
            for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                toys_x[loop_idx] <= 16'sd0;
                toys_y[loop_idx] <= 16'sd0;
            end
            for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                trees_x[loop_idx] <= 16'sd0;
                trees_y[loop_idx] <= 16'sd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    data_counter <= 6'd0;
                    toy_counter <= 6'd0;
                    tree_counter <= 4'd0;
                    tree_depth <= 3'd0;
                    total_length <= 32'd0;
                    curr_x <= 16'sd0;
                    curr_y <= 16'sd0;
                    cycle_count <= 16'd0;
                end
                
                LOAD: begin
                    busy <= 1'b1;
                    if (data_valid) begin
                        data_counter <= data_counter + 6'd1;
                        if (data_type == 1'b0) begin
                            // Store toy
                            toys_x[data_counter[3:0]] <= data_in[31:16];
                            toys_y[data_counter[3:0]] <= data_in[15:0];
                        end else begin
                            // Store tree
                            if (tree_depth < 3'd8) begin
                                trees_x[tree_depth] <= data_in[31:16];
                                trees_y[tree_depth] <= data_in[15:0];
                                tree_depth <= tree_depth + 3'd1;
                            end
                        end
                    end
                end
                
                CALC: begin
                    if (toy_counter < data_count[5:0]) begin
                        // Calculate vector to next toy
                        dx <= toys_x[toy_counter[3:0]] - curr_x;
                        dy <= toys_y[toy_counter[3:0]] - curr_y;
                        tree_counter <= 4'd0;
                        obstacle_flag <= 1'b0;
                    end
                    // Reset for next toy calculation
                    dist_approx <= 32'd0;
                    dist_penalty <= 32'd0;
                end
                
                CHECK: begin
                    // Check for obstacles using cross product approximation
                    if (tree_counter < tree_depth) begin
                        // Cross product: (tree_x - curr_x) * dy - (tree_y - curr_y) * dx
                        cross_prod <= ((trees_x[tree_counter] - curr_x) * dy) - ((trees_y[tree_counter] - curr_y) * dx);
                        
                        // Check if cross product is near zero (collision) and point is within segment
                        if (cross_prod < 16'd50 && cross_prod > -16'd50) begin
                            // Additional check: tree should be between current and target
                            // Simple heuristic: distance to tree < distance to toy
                            if ((trees_x[tree_counter] - curr_x) * (trees_x[tree_counter] - curr_x) + 
                                (trees_y[tree_counter] - curr_y) * (trees_y[tree_counter] - curr_y) < 
                                dx * dx + dy * dy) begin
                                obstacle_flag <= 1'b1;
                            end
                        end
                        tree_counter <= tree_counter + 4'd1;
                    end
                end
                
                DIST: begin
                    // Calculate approximate distance using max + min/2 (Q16.0 to Q16.16)
                    abs_dx <= (dx[15]) ? -dx : dx;
                    abs_dy <= (dy[15]) ? -dy : dy;
                    
                    if (abs_dx > abs_dy) begin
                        dist_approx <= {abs_dx, 16'd0} + ({abs_dy, 16'd0} >> 1);
                    end else begin
                        dist_approx <= {abs_dy, 16'd0} + ({abs_dx, 16'd0} >> 1);
                    end
                    
                    // If obstacle, multiply by 1.5 (add half)
                    if (obstacle_flag) begin
                        dist_penalty <= {abs_dx, 16'd0} + ({abs_dx, 16'd0} >> 1) + {abs_dy, 16'd0} + ({abs_dy, 16'd0} >> 1);
                        total_length <= total_length + ({abs_dx, 16'd0} + ({abs_dx, 16'd0} >> 1) + {abs_dy, 16'd0} + ({abs_dy, 16'd0} >> 1));
                    end else begin
                        if (abs_dx > abs_dy) begin
                            total_length <= total_length + ({abs_dx, 16'd0} + ({abs_dy, 16'd0} >> 1));
                        end else begin
                            total_length <= total_length + ({abs_dy, 16'd0} + ({abs_dx, 16'd0} >> 1));
                        end
                    end
                    
                    // Update current position to toy
                    curr_x <= toys_x[toy_counter[3:0]];
                    curr_y <= toys_y[toy_counter[3:0]];
                    
                    toy_counter <= toy_counter + 6'd1;
                end
                
                DONE: begin
                    result <= total_length;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
endmodule