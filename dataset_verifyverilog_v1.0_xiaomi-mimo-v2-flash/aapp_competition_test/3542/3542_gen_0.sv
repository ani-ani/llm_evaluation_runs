module RouteMinimizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] ax1,
    input [3:0] ay1,
    input [3:0] ax2,
    input [3:0] ay2,
    input [3:0] bx1,
    input [3:0] by1,
    input [3:0] bx2,
    input [3:0] by2,
    output reg [15:0] result,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CALC_DIST = 3'd1;
    localparam [2:0] GEN_PATH_A = 3'd2;
    localparam [2:0] GEN_PATH_B = 3'd3;
    localparam [2:0] CHECK_INTERSECT = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // Internal registers for coordinates
    reg [3:0] ax1_reg, ay1_reg, ax2_reg, ay2_reg;
    reg [3:0] bx1_reg, by1_reg, bx2_reg, by2_reg;
    
    // Distance registers
    reg [3:0] dA, dB;
    
    // Path generation counters
    reg [3:0] x_idx, y_idx;
    reg [3:0] step_idx;
    
    // Grid occupancy tracking - 9x9 grid, packed as 9 rows of 9 bits each
    // Using 9x9 = 81 bits, stored as 9 bytes for path A
    reg [8:0] path_a_grid [0:8];  // path_a_grid[y][x]
    reg [8:0] path_b_grid [0:8];  // path_b_grid[y][x]
    
    // Temporary path generation state
    reg [3:0] curr_x, curr_y;
    reg [3:0] target_x, target_y;
    reg [3:0] step_x, step_y;
    reg path_done;
    
    // Loop counters for intersection check
    reg [3:0] check_x, check_y;
    reg intersect_found;

    // Calculate absolute difference
    function automatic [3:0] abs_diff(input [3:0] a, input [3:0] b);
        begin
            if (a > b)
                abs_diff = a - b;
            else
                abs_diff = b - a;
        end
    endfunction

    // Signal: done pulse is high only in FINISH state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            possible <= 1'b1;
            cycle_count <= 4'd0;
            
            ax1_reg <= 4'd0; ay1_reg <= 4'd0; ax2_reg <= 4'd0; ay2_reg <= 4'd0;
            bx1_reg <= 4'd0; by1_reg <= 4'd0; bx2_reg <= 4'd0; by2_reg <= 4'd0;
            dA <= 4'd0; dB <= 4'd0;
            x_idx <= 4'd0; y_idx <= 4'd0; step_idx <= 4'd0;
            check_x <= 4'd0; check_y <= 4'd0;
            intersect_found <= 1'b0;
            
            // Initialize grid arrays
            for (y_idx = 0; y_idx < 9; y_idx = y_idx + 1) begin
                path_a_grid[y_idx] <= 9'b0;
                path_b_grid[y_idx] <= 9'b0;
            end
            
            curr_x <= 4'd0; curr_y <= 4'd0;
            target_x <= 4'd0; target_y <= 4'd0;
            step_x <= 4'd0; step_y <= 4'd0;
            path_done <= 1'b0;
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    possible <= 1'b1;
                    if (start) begin
                        ax1_reg <= ax1; ay1_reg <= ay1;
                        ax2_reg <= ax2; ay2_reg <= ay2;
                        bx1_reg <= bx1; by1_reg <= by1;
                        bx2_reg <= bx2; by2_reg <= by2;
                    end
                end
                
                CALC_DIST: begin
                    dA <= abs_diff(ax1_reg, ax2_reg) + abs_diff(ay1_reg, ay2_reg);
                    dB <= abs_diff(bx1_reg, bx2_reg) + abs_diff(by1_reg, by2_reg);
                    
                    // Reset path grids
                    for (y_idx = 0; y_idx < 9; y_idx = y_idx + 1) begin
                        path_a_grid[y_idx] <= 9'b0;
                        path_b_grid[y_idx] <= 9'b0;
                    end
                    
                    curr_x <= ax1_reg;
                    curr_y <= ay1_reg;
                    target_x <= ax2_reg;
                    target_y <= ay2_reg;
                    step_idx <= 4'd0;
                    path_done <= 1'b0;
                    
                    // Mark start point for path A
                    path_a_grid[ay1_reg] <= path_a_grid[ay1_reg] | (1 << ax1_reg);
                end
                
                GEN_PATH_A: begin
                    if (!path_done && step_idx < 8'd16) begin
                        step_idx <= step_idx + 4'd1;
                        
                        // Generate one step on path A
                        if (curr_x != target_x) begin
                            // Move horizontally
                            if (curr_x < target_x) begin
                                curr_x <= curr_x + 4'd1;
                                path_a_grid[curr_y] <= path_a_grid[curr_y] | (1 << (curr_x + 4'd1));
                            end else begin
                                curr_x <= curr_x - 4'd1;
                                path_a_grid[curr_y] <= path_a_grid[curr_y] | (1 << (curr_x - 4'd1));
                            end
                        end else if (curr_y != target_y) begin
                            // Move vertically
                            if (curr_y < target_y) begin
                                curr_y <= curr_y + 4'd1;
                                path_a_grid[curr_y + 4'd1] <= path_a_grid[curr_y + 4'd1] | (1 << curr_x);
                            end else begin
                                curr_y <= curr_y - 4'd1;
                                path_a_grid[curr_y - 4'd1] <= path_a_grid[curr_y - 4'd1] | (1 << curr_x);
                            end
                        end else begin
                            path_done <= 1'b1;
                        end
                    end
                    
                    // Mark end point
                    if (path_done || step_idx >= 8'd15) begin
                        path_a_grid[ay2_reg] <= path_a_grid[ay2_reg] | (1 << ax2_reg);
                    end
                    
                    if (path_done) begin
                        // Setup for path B
                        curr_x <= bx1_reg;
                        curr_y <= by1_reg;
                        target_x <= bx2_reg;
                        target_y <= by2_reg;
                        step_idx <= 4'd0;
                        path_done <= 1'b0;
                        
                        // Mark start point for path B
                        path_b_grid[by1_reg] <= path_b_grid[by1_reg] | (1 << bx1_reg);
                    end
                end
                
                GEN_PATH_B: begin
                    if (!path_done && step_idx < 8'd16) begin
                        step_idx <= step_idx + 4'd1;
                        
                        // Generate one step on path B
                        if (curr_x != target_x) begin
                            if (curr_x < target_x) begin
                                curr_x <= curr_x + 4'd1;
                                path_b_grid[curr_y] <= path_b_grid[curr_y] | (1 << (curr_x + 4'd1));
                            end else begin
                                curr_x <= curr_x - 4'd1;
                                path_b_grid[curr_y] <= path_b_grid[curr_y] | (1 << (curr_x - 4'd1));
                            end
                        end else if (curr_y != target_y) begin
                            if (curr_y < target_y) begin
                                curr_y <= curr_y + 4'd1;
                                path_b_grid[curr_y + 4'd1] <= path_b_grid[curr_y + 4'd1] | (1 << curr_x);
                            end else begin
                                curr_y <= curr_y - 4'd1;
                                path_b_grid[curr_y - 4'd1] <= path_b_grid[curr_y - 4'd1] | (1 << curr_x);
                            end
                        end else begin
                            path_done <= 1'b1;
                        end
                    end
                    
                    // Mark end point
                    if (path_done || step_idx >= 8'd15) begin
                        path_b_grid[by2_reg] <= path_b_grid[by2_reg] | (1 << bx2_reg);
                    end
                    
                    if (path_done) begin
                        // Setup for intersection check
                        check_y <= 4'd0;
                        check_x <= 4'd0;
                        intersect_found <= 1'b0;
                    end
                end
                
                CHECK_INTERSECT: begin
                    if (!intersect_found && check_y < 9) begin
                        // Check intersection at this vertex
                        if ((path_a_grid[check_y] & path_b_grid[check_y]) != 9'b0) begin
                            intersect_found <= 1'b1;
                            possible <= 1'b0;
                        end
                        
                        // Move to next position
                        if (check_x < 8'd8) begin
                            check_x <= check_x + 4'd1;
                        end else begin
                            check_x <= 4'd0;
                            check_y <= check_y + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (!intersect_found) begin
                        result <= {8'd0, dA} + {8'd0, dB};
                        possible <= 1'b1;
                    end else begin
                        result <= 16'd0;
                        possible <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            cycle_count <= cycle_count + 4'd1;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC_DIST;
                else
                    next_state = IDLE;
            end
            
            CALC_DIST: begin
                next_state = GEN_PATH_A;
            end
            
            GEN_PATH_A: begin
                if (path_done)
                    next_state = GEN_PATH_B;
                else
                    next_state = GEN_PATH_A;
            end
            
            GEN_PATH_B: begin
                if (path_done)
                    next_state = CHECK_INTERSECT;
                else
                    next_state = GEN_PATH_B;
            end
            
            CHECK_INTERSECT: begin
                if (intersect_found || (check_y >= 9)) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_INTERSECT;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule