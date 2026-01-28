module scroll_code_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] grid [2:0][2:0],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] FIND_ZEROS = 3'd2;
    localparam [2:0] ENUMERATE = 3'd3;
    localparam [2:0] CHECK_CONSTRAINTS = 3'd4;
    localparam [2:0] COUNT_VALID = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Grid storage (copy of input)
    reg [3:0] grid_reg [2:0][2:0];
    
    // Zero positions and count
    reg [3:0] zero_positions [4:0];  // Store (i*3+j) for up to 5 zeros
    reg [2:0] zero_count;
    reg [2:0] zero_idx;
    
    // Candidate generation
    reg [3:0] candidate_grid [2:0][2:0];
    reg [4:0] candidate_idx;  // For iterating through candidates
    reg [4:0] num_candidates;  // 9^N
    
    // Temporary registers for calculations
    reg [3:0] temp_l, temp_r, temp_u;
    reg [7:0] idx;  // For loops
    reg [15:0] count;
    reg valid_flag;
    reg [3:0] div_temp;
    
    // Helper: calculate 9^N
    function automatic [4:0] power9(input [2:0] n);
        reg [4:0] result;
        integer i;
        begin
            result = 5'd1;
            for (i = 0; i < n; i = i + 1) begin
                result = result * 5'd9;
            end
            power9 = result;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            zero_count <= 3'd0;
            zero_idx <= 3'd0;
            candidate_idx <= 5'd0;
            num_candidates <= 5'd0;
            count <= 16'd0;
            valid_flag <= 1'b0;
            // Initialize grid arrays
            for (idx = 0; idx < 3; idx = idx + 1) begin
                grid_reg[idx][0] <= 4'd0;
                grid_reg[idx][1] <= 4'd0;
                grid_reg[idx][2] <= 4'd0;
                candidate_grid[idx][0] <= 4'd0;
                candidate_grid[idx][1] <= 4'd0;
                candidate_grid[idx][2] <= 4'd0;
            end
            // Initialize zero_positions
            for (idx = 0; idx < 5; idx = idx + 1) begin
                zero_positions[idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= LOAD_GRID;
                        cycle_count <= cycle_count + 16'd1;
                    end
                end

                LOAD_GRID: begin
                    // Copy input grid to grid_reg
                    for (idx = 0; idx < 3; idx = idx + 1) begin
                        grid_reg[idx][0] <= grid[idx][0];
                        grid_reg[idx][1] <= grid[idx][1];
                        grid_reg[idx][2] <= grid[idx][2];
                    end
                    count <= 16'd0;
                    zero_count <= 3'd0;
                    state <= FIND_ZEROS;
                    cycle_count <= cycle_count + 16'd1;
                end

                FIND_ZEROS: begin
                    // Scan grid for zeros and record positions
                    // Check (0,0)
                    if (grid_reg[0][0] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd0;  // (0,0) = 0
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (0,1)
                    if (grid_reg[0][1] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd1;  // (0,1) = 1
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (0,2)
                    if (grid_reg[0][2] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd2;  // (0,2) = 2
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (1,0)
                    if (grid_reg[1][0] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd3;  // (1,0) = 3
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (1,1)
                    if (grid_reg[1][1] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd4;  // (1,1) = 4
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (1,2)
                    if (grid_reg[1][2] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd5;  // (1,2) = 5
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (2,0)
                    if (grid_reg[2][0] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd6;  // (2,0) = 6
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (2,1)
                    if (grid_reg[2][1] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd7;  // (2,1) = 7
                        zero_count <= zero_count + 3'd1;
                    end
                    // Check (2,2)
                    if (grid_reg[2][2] == 4'd0 && zero_count < 3'd5) begin
                        zero_positions[zero_count] <= 4'd8;  // (2,2) = 8
                        zero_count <= zero_count + 3'd1;
                    end
                    
                    // Calculate number of candidates
                    num_candidates <= power9(zero_count);
                    candidate_idx <= 5'd0;
                    state <= ENUMERATE;
                    cycle_count <= cycle_count + 16'd1;
                end

                ENUMERATE: begin
                    // Reset candidate grid to original values
                    for (idx = 0; idx < 3; idx = idx + 1) begin
                        candidate_grid[idx][0] <= grid_reg[idx][0];
                        candidate_grid[idx][1] <= grid_reg[idx][1];
                        candidate_grid[idx][2] <= grid_reg[idx][2];
                    end
                    
                    // Fill zeros with candidate values (base-9 representation of candidate_idx)
                    // We'll use a for loop to decode the number
                    begin : ENUMERATE_BLOCK
                        integer j;
                        reg [4:0] temp_val;
                        reg [3:0] digit;
                        reg [2:0] pos;
                        
                        temp_val = candidate_idx;
                        for (j = 0; j < 5; j = j + 1) begin
                            if (j < zero_count) begin
                                pos = zero_positions[j][2:0];  // Get position index
                                digit = temp_val % 4'd9;  // Extract digit (0-8)
                                if (digit == 4'd0) begin
                                    // Skip invalid digit 0
                                end else begin
                                    case (pos)
                                        3'd0: candidate_grid[0][0] <= digit + 4'd1;  // (0,0)
                                        3'd1: candidate_grid[0][1] <= digit + 4'd1;  // (0,1)
                                        3'd2: candidate_grid[0][2] <= digit + 4'd1;  // (0,2)
                                        3'd3: candidate_grid[1][0] <= digit + 4'd1;  // (1,0)
                                        3'd4: candidate_grid[1][1] <= digit + 4'd1;  // (1,1)
                                        3'd5: candidate_grid[1][2] <= digit + 4'd1;  // (1,2)
                                        3'd6: candidate_grid[2][0] <= digit + 4'd1;  // (2,0)
                                        3'd7: candidate_grid[2][1] <= digit + 4'd1;  // (2,1)
                                        3'd8: candidate_grid[2][2] <= digit + 4'd1;  // (2,2)
                                    endcase
                                end
                                temp_val = temp_val / 4'd9;
                            end
                        end
                    end
                    
                    valid_flag <= 1'b1;
                    state <= CHECK_CONSTRAINTS;
                    cycle_count <= cycle_count + 16'd1;
                end

                CHECK_CONSTRAINTS: begin
                    // Check row uniqueness
                    // Row 0
                    if ((candidate_grid[0][0] == candidate_grid[0][1]) || 
                        (candidate_grid[0][1] == candidate_grid[0][2]) ||
                        (candidate_grid[0][0] == candidate_grid[0][2]) ||
                        (candidate_grid[0][0] == 4'd0) ||
                        (candidate_grid[0][1] == 4'd0) ||
                        (candidate_grid[0][2] == 4'd0)) begin
                        valid_flag <= 1'b0;
                    end
                    // Row 1
                    else if ((candidate_grid[1][0] == candidate_grid[1][1]) || 
                             (candidate_grid[1][1] == candidate_grid[1][2]) ||
                             (candidate_grid[1][0] == candidate_grid[1][2]) ||
                             (candidate_grid[1][0] == 4'd0) ||
                             (candidate_grid[1][1] == 4'd0) ||
                             (candidate_grid[1][2] == 4'd0)) begin
                        valid_flag <= 1'b0;
                    end
                    // Row 2
                    else if ((candidate_grid[2][0] == candidate_grid[2][1]) || 
                             (candidate_grid[2][1] == candidate_grid[2][2]) ||
                             (candidate_grid[2][0] == candidate_grid[2][2]) ||
                             (candidate_grid[2][0] == 4'd0) ||
                             (candidate_grid[2][1] == 4'd0) ||
                             (candidate_grid[2][2] == 4'd0)) begin
                        valid_flag <= 1'b0;
                    end
                    else begin
                        // Check L-shape constraints for rows 0 and 1 (not top row, not rightmost column)
                        // For (1,0): u = candidate_grid[0][0], l = candidate_grid[1][0], r = candidate_grid[1][1]
                        temp_u = candidate_grid[0][0];
                        temp_l = candidate_grid[1][0];
                        temp_r = candidate_grid[1][1];
                        
                        if ((temp_u == temp_l * temp_r) ||
                            (temp_u == temp_l + temp_r) ||
                            (temp_u == (temp_l > temp_r ? temp_l - temp_r : temp_r - temp_l)) ||
                            ((temp_r != 4'd0 && temp_l % temp_r == 4'd0 && temp_u == temp_l / temp_r)) ||
                            ((temp_l != 4'd0 && temp_r % temp_l == 4'd0 && temp_u == temp_r / temp_l))) begin
                            // Check (1,1): u = candidate_grid[0][1], l = candidate_grid[1][1], r = candidate_grid[1][2]
                            temp_u = candidate_grid[0][1];
                            temp_l = candidate_grid[1][1];
                            temp_r = candidate_grid[1][2];
                            
                            if ((temp_u == temp_l * temp_r) ||
                                (temp_u == temp_l + temp_r) ||
                                (temp_u == (temp_l > temp_r ? temp_l - temp_r : temp_r - temp_l)) ||
                                ((temp_r != 4'd0 && temp_l % temp_r == 4'd0 && temp_u == temp_l / temp_r)) ||
                                ((temp_l != 4'd0 && temp_r % temp_l == 4'd0 && temp_u == temp_r / temp_l))) begin
                                valid_flag <= 1'b1;
                            end else begin
                                valid_flag <= 1'b0;
                            end
                        end else begin
                            valid_flag <= 1'b0;
                        end
                    end
                    
                    state <= COUNT_VALID;
                    cycle_count <= cycle_count + 16'd1;
                end

                COUNT_VALID: begin
                    if (valid_flag) begin
                        count <= count + 16'd1;
                    end
                    
                    // Check if we've enumerated all candidates
                    if (candidate_idx < num_candidates - 5'd1) begin
                        candidate_idx <= candidate_idx + 5'd1;
                        state <= ENUMERATE;
                    end else begin
                        result <= count;
                        state <= FINISH;
                    end
                    cycle_count <= cycle_count + 16'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                    cycle_count <= cycle_count + 16'd1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule