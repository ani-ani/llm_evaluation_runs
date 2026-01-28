module MaxPerimeterFinder(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [7:0],
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_PS   = 3'd1;  // Calculate prefix sums
    localparam [2:0] ITERATE   = 3'd2;  // Iterate over rectangles
    localparam [2:0] CHECK     = 3'd3;  // Check if rectangle is valid
    localparam [2:0] UPDATE    = 3'd4;  // Update max perimeter
    localparam [2:0] FINISH    = 3'd5;  // Done state
    
    reg [2:0] state, next_state;
    
    // Variables for rectangle iteration
    reg [2:0] r1, c1, r2, c2;
    reg [2:0] r1_next, c1_next, r2_next, c2_next;
    
    // Prefix sum array (2D - 8x8, 4-bit each since max sum is 64)
    reg [5:0] ps [7:0][7:0];
    
    // Compute prefix sum for each cell: ps[i][j] = sum of grid[0..i][0..j]
    wire [5:0] ps_calc [7:0][7:0];
    
    // Calculate prefix sum using combinational logic
    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : ps_row
            for (j = 0; j < 8; j = j + 1) begin : ps_col
                if (i == 0 && j == 0) begin
                    assign ps_calc[i][j] = grid[i][j];
                end else if (i == 0) begin
                    assign ps_calc[i][j] = ps_calc[i][j-1] + grid[i][j];
                end else if (j == 0) begin
                    assign ps_calc[i][j] = ps_calc[i-1][j] + grid[i][j];
                end else begin
                    assign ps_calc[i][j] = ps_calc[i-1][j] + ps_calc[i][j-1] - ps_calc[i-1][j-1] + grid[i][j];
                end
            end
        end
    endgenerate
    
    // Rectangle area and validity check
    wire [5:0] rect_area;
    wire rect_valid;
    wire [5:0] sum_top_left, sum_top_right, sum_bottom_left, sum_bottom_right;
    
    // Get the four corners for the rectangle sum
    assign sum_top_left = (r1 > 0 && c1 > 0) ? ps[r1-1][c1-1] : 6'd0;
    assign sum_top_right = (r1 > 0) ? ps[r1-1][c2] : 6'd0;
    assign sum_bottom_left = (c1 > 0) ? ps[r2][c1-1] : 6'd0;
    assign sum_bottom_right = ps[r2][c2];
    
    // Rectangle sum using inclusion-exclusion
    assign rect_area = sum_bottom_right + sum_top_left - sum_top_right - sum_bottom_left;
    
    // Rectangle is valid if area equals number of cells
    wire [5:0] expected_area;
    assign expected_area = (r2 - r1 + 1) * (c2 - c1 + 1);
    assign rect_valid = (rect_area == expected_area);
    
    // Perimeter calculation
    wire [15:0] perimeter;
    wire [15:0] width, height;
    assign width = c2 - c1 + 1;
    assign height = r2 - r1 + 1;
    assign perimeter = (width + height) * 2;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State transition logic
    always @(*) begin
        next_state = state;
        r1_next = r1;
        c1_next = c1;
        r2_next = r2;
        c2_next = c2;
        
        case (state)
            IDLE: begin
                if (start) next_state = CALC_PS;
            end
            
            CALC_PS: begin
                next_state = ITERATE;
            end
            
            ITERATE: begin
                if (r1 == 3'd7 && c1 == 3'd7 && r2 == 3'd7 && c2 == 3'd7) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                if (rect_valid) begin
                    next_state = UPDATE;
                end else begin
                    // Move to next rectangle
                    if (c2 < 3'd7) begin
                        c2_next = c2 + 3'd1;
                    end else begin
                        c2_next = c1;
                        if (r2 < 3'd7) begin
                            r2_next = r2 + 3'd1;
                        end else begin
                            r2_next = r1;
                            if (c1 < 3'd7) begin
                                c1_next = c1 + 3'd1;
                            end else begin
                                c1_next = 3'd0;
                                if (r1 < 3'd7) begin
                                    r1_next = r1 + 3'd1;
                                end
                            end
                        end
                    end
                    next_state = ITERATE;
                end
            end
            
            UPDATE: begin
                // Move to next rectangle after updating
                if (c2 < 3'd7) begin
                    c2_next = c2 + 3'd1;
                end else begin
                    c2_next = c1;
                    if (r2 < 3'd7) begin
                        r2_next = r2 + 3'd1;
                    end else begin
                        r2_next = r1;
                        if (c1 < 3'd7) begin
                            c1_next = c1 + 3'd1;
                        end else begin
                            c1_next = 3'd0;
                            if (r1 < 3'd7) begin
                                r1_next = r1 + 3'd1;
                            end
                        end
                    end
                end
                next_state = ITERATE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            r1 <= 3'd0;
            c1 <= 3'd0;
            r2 <= 3'd0;
            c2 <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize ps array
            ps[0][0] <= 6'd0; ps[0][1] <= 6'd0; ps[0][2] <= 6'd0; ps[0][3] <= 6'd0;
            ps[0][4] <= 6'd0; ps[0][5] <= 6'd0; ps[0][6] <= 6'd0; ps[0][7] <= 6'd0;
            ps[1][0] <= 6'd0; ps[1][1] <= 6'd0; ps[1][2] <= 6'd0; ps[1][3] <= 6'd0;
            ps[1][4] <= 6'd0; ps[1][5] <= 6'd0; ps[1][6] <= 6'd0; ps[1][7] <= 6'd0;
            ps[2][0] <= 6'd0; ps[2][1] <= 6'd0; ps[2][2] <= 6'd0; ps[2][3] <= 6'd0;
            ps[2][4] <= 6'd0; ps[2][5] <= 6'd0; ps[2][6] <= 6'd0; ps[2][7] <= 6'd0;
            ps[3][0] <= 6'd0; ps[3][1] <= 6'd0; ps[3][2] <= 6'd0; ps[3][3] <= 6'd0;
            ps[3][4] <= 6'd0; ps[3][5] <= 6'd0; ps[3][6] <= 6'd0; ps[3][7] <= 6'd0;
            ps[4][0] <= 6'd0; ps[4][1] <= 6'd0; ps[4][2] <= 6'd0; ps[4][3] <= 6'd0;
            ps[4][4] <= 6'd0; ps[4][5] <= 6'd0; ps[4][6] <= 6'd0; ps[4][7] <= 6'd0;
            ps[5][0] <= 6'd0; ps[5][1] <= 6'd0; ps[5][2] <= 6'd0; ps[5][3] <= 6'd0;
            ps[5][4] <= 6'd0; ps[5][5] <= 6'd0; ps[5][6] <= 6'd0; ps[5][7] <= 6'd0;
            ps[6][0] <= 6'd0; ps[6][1] <= 6'd0; ps[6][2] <= 6'd0; ps[6][3] <= 6'd0;
            ps[6][4] <= 6'd0; ps[6][5] <= 6'd0; ps[6][6] <= 6'd0; ps[6][7] <= 6'd0;
            ps[7][0] <= 6'd0; ps[7][1] <= 6'd0; ps[7][2] <= 6'd0; ps[7][3] <= 6'd0;
            ps[7][4] <= 6'd0; ps[7][5] <= 6'd0; ps[7][6] <= 6'd0; ps[7][7] <= 6'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            r1 <= r1_next;
            c1 <= c1_next;
            r2 <= r2_next;
            c2 <= c2_next;
            
            // Update cycle count
            if (state == ITERATE || state == CHECK || state == UPDATE) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        result <= 16'd0;
                        cycle_count <= 8'd0;
                    end
                end
                
                CALC_PS: begin
                    // Load calculated prefix sums into registers
                    ps[0][0] <= ps_calc[0][0]; ps[0][1] <= ps_calc[0][1];
                    ps[0][2] <= ps_calc[0][2]; ps[0][3] <= ps_calc[0][3];
                    ps[0][4] <= ps_calc[0][4]; ps[0][5] <= ps_calc[0][5];
                    ps[0][6] <= ps_calc[0][6]; ps[0][7] <= ps_calc[0][7];
                    ps[1][0] <= ps_calc[1][0]; ps[1][1] <= ps_calc[1][1];
                    ps[1][2] <= ps_calc[1][2]; ps[1][3] <= ps_calc[1][3];
                    ps[1][4] <= ps_calc[1][4]; ps[1][5] <= ps_calc[1][5];
                    ps[1][6] <= ps_calc[1][6]; ps[1][7] <= ps_calc[1][7];
                    ps[2][0] <= ps_calc[2][0]; ps[2][1] <= ps_calc[2][1];
                    ps[2][2] <= ps_calc[2][2]; ps[2][3] <= ps_calc[2][3];
                    ps[2][4] <= ps_calc[2][4]; ps[2][5] <= ps_calc[2][5];
                    ps[2][6] <= ps_calc[2][6]; ps[2][7] <= ps_calc[2][7];
                    ps[3][0] <= ps_calc[3][0]; ps[3][1] <= ps_calc[3][1];
                    ps[3][2] <= ps_calc[3][2]; ps[3][3] <= ps_calc[3][3];
                    ps[3][4] <= ps_calc[3][4]; ps[3][5] <= ps_calc[3][5];
                    ps[3][6] <= ps_calc[3][6]; ps[3][7] <= ps_calc[3][7];
                    ps[4][0] <= ps_calc[4][0]; ps[4][1] <= ps_calc[4][1];
                    ps[4][2] <= ps_calc[4][2]; ps[4][3] <= ps_calc[4][3];
                    ps[4][4] <= ps_calc[4][4]; ps[4][5] <= ps_calc[4][5];
                    ps[4][6] <= ps_calc[4][6]; ps[4][7] <= ps_calc[4][7];
                    ps[5][0] <= ps_calc[5][0]; ps[5][1] <= ps_calc[5][1];
                    ps[5][2] <= ps_calc[5][2]; ps[5][3] <= ps_calc[5][3];
                    ps[5][4] <= ps_calc[5][4]; ps[5][5] <= ps_calc[5][5];
                    ps[5][6] <= ps_calc[5][6]; ps[5][7] <= ps_calc[5][7];
                    ps[6][0] <= ps_calc[6][0]; ps[6][1] <= ps_calc[6][1];
                    ps[6][2] <= ps_calc[6][2]; ps[6][3] <= ps_calc[6][3];
                    ps[6][4] <= ps_calc[6][4]; ps[6][5] <= ps_calc[6][5];
                    ps[6][6] <= ps_calc[6][6]; ps[6][7] <= ps_calc[6][7];
                    ps[7][0] <= ps_calc[7][0]; ps[7][1] <= ps_calc[7][1];
                    ps[7][2] <= ps_calc[7][2]; ps[7][3] <= ps_calc[7][3];
                    ps[7][4] <= ps_calc[7][4]; ps[7][5] <= ps_calc[7][5];
                    ps[7][6] <= ps_calc[7][6]; ps[7][7] <= ps_calc[7][7];
                end
                
                ITERATE: begin
                    // No state change, just transition
                end
                
                CHECK: begin
                    // If invalid, next_state handles moving to next rectangle
                    // (no register updates needed)
                end
                
                UPDATE: begin
                    // Update maximum perimeter
                    if (perimeter > result) begin
                        result <= perimeter;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // Default case
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != FINISH) begin
                state <= FINISH;
            end
        end
    end
endmodule