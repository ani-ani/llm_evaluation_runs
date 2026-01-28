module TwoLinesCover #(
    parameter MAX_POINTS = 8,
    parameter COORD_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] count,
    input wire signed [COORD_WIDTH-1:0] x [0:MAX_POINTS-1],
    input wire signed [COORD_WIDTH-1:0] y [0:MAX_POINTS-1],
    output reg success,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [2:0] i, j, k;  // Loop counters
    reg [2:0] remaining_count;
    reg [2:0] first_idx, second_idx;
    reg signed [15:0] cross1, cross2;  // Cross product results (16-bit)
    reg signed [15:0] vec1_x, vec1_y, vec2_x, vec2_y;
    reg found_line;
    reg collinear_check;
    reg [2:0] non_line_points [0:MAX_POINTS-1];
    reg [2:0] non_line_count;
    reg [2:0] pair_i, pair_j;
    reg [2:0] current_idx;
    
    // Internal reset state for arrays
    integer m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            success <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            remaining_count <= 3'd0;
            first_idx <= 3'd0;
            second_idx <= 3'd0;
            cross1 <= 16'sd0;
            cross2 <= 16'sd0;
            vec1_x <= 16'sd0;
            vec1_y <= 16'sd0;
            vec2_x <= 16'sd0;
            vec2_y <= 16'sd0;
            found_line <= 1'b0;
            collinear_check <= 1'b0;
            non_line_count <= 3'd0;
            pair_i <= 3'd0;
            pair_j <= 3'd0;
            current_idx <= 3'd0;
            for (m = 0; m < MAX_POINTS; m = m + 1) begin
                non_line_points[m] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    success <= 1'b0;
                    if (start) begin
                        // Start computation
                        if (count <= 3'd2) begin
                            success <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Initialize for computation
                            pair_i <= 3'd0;
                            pair_j <= 3'd1;
                            found_line <= 1'b0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Check if we already found a valid configuration
                    if (found_line) begin
                        success <= 1'b1;
                        state <= DONE_STATE;
                    end else if (pair_i >= count - 3'd2) begin
                        // Exhausted all pairs without success
                        success <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Check current pair (pair_i, pair_j)
                        // Build list of points NOT on line defined by (pair_i, pair_j)
                        non_line_count <= 3'd0;
                        for (k = 3'd0; k < count; k = k + 3'd1) begin
                            // Compute cross product for point k relative to line i-j
                            // vec1 = (x[j]-x[i], y[j]-y[i])
                            // vec2 = (x[k]-x[i], y[k]-y[i])
                            // cross = vec1.x * vec2.y - vec1.y * vec2.x
                            // Use 16-bit arithmetic
                            vec1_x <= { {8{x[pair_j][COORD_WIDTH-1]}}, x[pair_j] } - { {8{x[pair_i][COORD_WIDTH-1]}}, x[pair_i] };
                            vec1_y <= { {8{y[pair_j][COORD_WIDTH-1]}}, y[pair_j] } - { {8{y[pair_i][COORD_WIDTH-1]}}, y[pair_i] };
                            vec2_x <= { {8{x[k][COORD_WIDTH-1]}}, x[k] } - { {8{x[pair_i][COORD_WIDTH-1]}}, x[pair_i] };
                            vec2_y <= { {8{y[k][COORD_WIDTH-1]}}, y[k] } - { {8{y[pair_i][COORD_WIDTH-1]}}, y[pair_i] };
                            
                            // Delayed evaluation: need to store results
                            // This requires pipelining or re-evaluation in next cycle
                            // Simplified: Assume combinational check in same cycle
                            // For synthesis with loops, we'll use a manual unrolled approach
                        end
                        
                        // Move to next pair
                        pair_j <= pair_j + 3'd1;
                        if (pair_j >= count - 3'd1) begin
                            pair_j <= pair_i + 3'd2;
                            pair_i <= pair_i + 3'd1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for cross-product checks
    // Since loops with complex logic are problematic, we use manual unrolling
    // This section runs in parallel with the state machine
    
    reg signed [15:0] vec1_x_comb, vec1_y_comb;
    reg signed [15:0] vec2_x_comb, vec2_y_comb;
    reg signed [15:0] cross_comb;
    reg [2:0] check_idx;
    reg [2:0] check_count;
    reg [2:0] check_list [0:MAX_POINTS-1];
    reg check_collinear;
    reg check_fail;
    
    always @(*) begin
        // Default values
        check_collinear = 1'b1;
        check_fail = 1'b0;
        check_count = 3'd0;
        
        if (state == COMPUTE && !found_line && count > 3'd2) begin
            // First, collect points not on line (pair_i, pair_j)
            for (check_idx = 3'd0; check_idx < count; check_idx = check_idx + 3'd1) begin
                vec1_x_comb = { {8{x[pair_j][COORD_WIDTH-1]}}, x[pair_j] } - { {8{x[pair_i][COORD_WIDTH-1]}}, x[pair_i] };
                vec1_y_comb = { {8{y[pair_j][COORD_WIDTH-1]}}, y[pair_j] } - { {8{y[pair_i][COORD_WIDTH-1]}}, y[pair_i] };
                vec2_x_comb = { {8{x[check_idx][COORD_WIDTH-1]}}, x[check_idx] } - { {8{x[pair_i][COORD_WIDTH-1]}}, x[pair_i] };
                vec2_y_comb = { {8{y[check_idx][COORD_WIDTH-1]}}, y[check_idx] } - { {8{y[pair_i][COORD_WIDTH-1]}}, y[pair_i] };
                cross_comb = vec1_x_comb * vec2_y_comb - vec1_y_comb * vec2_x_comb;
                
                if (cross_comb != 16'sd0) begin
                    // Point not on line
                    if (check_count < MAX_POINTS) begin
                        check_list[check_count] = check_idx;
                        check_count = check_count + 3'd1;
                    end
                end
            end
            
            // Check if remaining points are collinear
            if (check_count <= 3'd1) begin
                // 0 or 1 point left: always collinear
                found_line = 1'b1;
            end else begin
                // At least 2 points: check collinearity
                // Take first two points
                vec1_x_comb = { {8{x[check_list[1]][COORD_WIDTH-1]}}, x[check_list[1]] } - { {8{x[check_list[0]][COORD_WIDTH-1]}}, x[check_list[0]] };
                vec1_y_comb = { {8{y[check_list[1]][COORD_WIDTH-1]}}, y[check_list[1]] } - { {8{y[check_list[0]][COORD_WIDTH-1]}}, y[check_list[0]] };
                
                for (check_idx = 3'd2; check_idx < check_count; check_idx = check_idx + 3'd1) begin
                    vec2_x_comb = { {8{x[check_list[check_idx]][COORD_WIDTH-1]}}, x[check_list[check_idx]] } - { {8{x[check_list[0]][COORD_WIDTH-1]}}, x[check_list[0]] };
                    vec2_y_comb = { {8{y[check_list[check_idx]][COORD_WIDTH-1]}}, y[check_list[check_idx]] } - { {8{y[check_list[0]][COORD_WIDTH-1]}}, y[check_list[0]] };
                    cross_comb = vec1_x_comb * vec2_y_comb - vec1_y_comb * vec2_x_comb;
                    if (cross_comb != 16'sd0) begin
                        check_collinear = 1'b0;
                    end
                end
                
                if (check_collinear) begin
                    found_line = 1'b1;
                end
            end
        end
    end

endmodule