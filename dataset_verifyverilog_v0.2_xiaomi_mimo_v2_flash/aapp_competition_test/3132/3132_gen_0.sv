module building_detector(
    input clk,
    input rst_n,
    input start,
    input [15:0] grid_row_0,
    input [15:0] grid_row_1,
    input [15:0] grid_row_2,
    input [15:0] grid_row_3,
    input [15:0] grid_row_4,
    input [15:0] grid_row_5,
    input [15:0] grid_row_6,
    input [15:0] grid_row_7,
    input [15:0] grid_row_8,
    input [15:0] grid_row_9,
    input [15:0] grid_row_10,
    input [15:0] grid_row_11,
    input [15:0] grid_row_12,
    input [15:0] grid_row_13,
    input [15:0] grid_row_14,
    input [15:0] grid_row_15,
    output reg [3:0] building1_row,
    output reg [3:0] building1_col,
    output reg [3:0] building1_size,
    output reg [3:0] building2_row,
    output reg [3:0] building2_col,
    output reg [3:0] building2_size,
    output reg done
);

    // Grid memory (16x16) to store input data
    reg [15:0] grid [0:15];
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam VERIFY = 2'b10;
    localparam OUTPUT = 2'b11;
    
    reg [1:0] state;
    reg [3:0] r, c, s; // row, col, size counters
    reg [3:0] next_r, next_c, next_s;
    reg verify_pass;
    reg [3:0] v_r, v_c; // verification counters
    
    // Buildings storage
    reg [3:0] b1_r, b1_c, b1_s;
    reg [3:0] b2_r, b2_c, b2_s;
    reg found_first;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            building1_row <= 4'b0;
            building1_col <= 4'b0;
            building1_size <= 4'b0;
            building2_row <= 4'b0;
            building2_col <= 4'b0;
            building2_size <= 4'b0;
            done <= 1'b0;
            r <= 4'b0;
            c <= 4'b0;
            s <= 4'b0;
            b1_r <= 4'b0; b1_c <= 4'b0; b1_s <= 4'b0;
            b2_r <= 4'b0; b2_c <= 4'b0; b2_s <= 4'b0;
            found_first <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load grid data into internal memory
                        grid[0] <= grid_row_0;
                        grid[1] <= grid_row_1;
                        grid[2] <= grid_row_2;
                        grid[3] <= grid_row_3;
                        grid[4] <= grid_row_4;
                        grid[5] <= grid_row_5;
                        grid[6] <= grid_row_6;
                        grid[7] <= grid_row_7;
                        grid[8] <= grid_row_8;
                        grid[9] <= grid_row_9;
                        grid[10] <= grid_row_10;
                        grid[11] <= grid_row_11;
                        grid[12] <= grid_row_12;
                        grid[13] <= grid_row_13;
                        grid[14] <= grid_row_14;
                        grid[15] <= grid_row_15;
                        
                        r <= 4'b0;
                        c <= 4'b0;
                        s <= 4'd1; // Start size from 1
                        found_first <= 1'b0;
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    // Iterate: r (0-15), c (0-15), s (1-16)
                    if (r <= 4'd15) begin
                        // Check if square of size 's' fits at (r,c)
                        if (r + s <= 16 && c + s <= 16) begin
                            // Start Verification
                            v_r <= r;
                            v_c <= c;
                            verify_pass <= 1'b1; // Assume pass until proven otherwise
                            state <= VERIFY;
                        end else begin
                            // Move to next position
                            if (c < 4'd15) begin
                                c <= c + 1;
                            end else begin
                                c <= 0;
                                if (s < 4'd16) begin
                                    s <= s + 1;
                                end else begin
                                    s <= 4'd1;
                                    if (r < 4'd15) begin
                                        r <= r + 1;
                                    end else begin
                                        // Scanned all, go to output (even if not 2 found)
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end

                VERIFY: begin
                    // Check if grid[v_r][v_c] is 0
                    if (grid[v_r][v_c] == 1'b0) begin
                        verify_pass <= 1'b0;
                    end
                    
                    // Move to next cell in square
                    if (v_c < c + s - 1) begin
                        v_c <= v_c + 1;
                    end else begin
                        v_c <= c;
                        if (v_r < r + s - 1) begin
                            v_r <= v_r + 1;
                        end else begin
                            // Verification Complete
                            if (verify_pass) begin
                                // Check overlap with existing buildings
                                if (found_first) begin
                                    // Check overlap with b1
                                    if (r < b1_r + b1_s && r + s > b1_r && c < b1_c + b1_s && c + s > b1_c) begin
                                        // Overlaps, ignore
                                        state <= SCAN; 
                                    end else begin
                                        // Found second building
                                        b2_r <= r;
                                        b2_c <= c;
                                        b2_s <= s;
                                        state <= OUTPUT;
                                    end
                                end else begin
                                    // Store first building
                                    b1_r <= r;
                                    b1_c <= c;
                                    b1_s <= s;
                                    found_first <= 1'b1;
                                    state <= SCAN;
                                end
                            end else begin
                                // Not valid, continue scan
                                state <= SCAN;
                            end
                            
                            // Advance counters for next scan (after VERIFY return)
                            // We need to update the main r, c, s counters based on current state logic
                            // The SCAN state logic handles iteration, so we just transition to SCAN
                            // However, we must ensure the counters are updated to the next position
                            // because SCAN will process the current r, c, s again if we don't change them.
                            // So we update r, c, s here to point to the NEXT state that SCAN would calculate.
                            
                            if (c < 4'd15) begin
                                next_c = c + 1;
                                next_r = r;
                                next_s = s;
                            end else begin
                                next_c = 0;
                                if (s < 4'd16) begin
                                    next_s = s + 1;
                                    next_r = r;
                                end else begin
                                    next_s = 1;
                                    if (r < 4'd15) begin
                                        next_r = r + 1;
                                    end else begin
                                        next_r = r; // End of grid, irrelevant
                                    end
                                end
                            end
                            c <= next_c;
                            r <= next_r;
                            s <= next_s;
                        end
                    end
                end

                OUTPUT: begin
                    building1_row <= b1_r;
                    building1_col <= b1_c;
                    building1_size <= b1_s;
                    building2_row <= b2_r;
                    building2_col <= b2_c;
                    building2_size <= b2_s;
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
