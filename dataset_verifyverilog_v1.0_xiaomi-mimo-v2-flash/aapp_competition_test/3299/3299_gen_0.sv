module magic_checkerboard (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] grid_in [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] CHECK_CONFLICTS = 3'd1;
    localparam [2:0] PROPAGATE       = 3'd2;
    localparam [2:0] CALCULATE_SUM   = 3'd3;
    localparam [2:0] FINISHED        = 3'd4;
    localparam [2:0] ERROR_STATE     = 3'd5;

    // Grid indices mapping: row 0-3, col 0-3
    // grid_val indices: 0..15
    // index = row*4 + col

    reg [2:0] state, next_state;
    reg [15:0] grid_val [0:15];
    reg [15:0] temp_result;
    reg [3:0] index;           // 0-15 for grid access
    reg [3:0] cycle_counter;   // Max 64 cycles
    
    // Intermediate signals for boundary checks
    wire [3:0] row, col;
    wire [3:0] top_idx, left_idx, bottom_idx, right_idx;
    wire signed [15:0] top_val, left_val, bottom_val, right_val;
    wire signed [15:0] current_val;
    
    // Calculate indices safely
    assign row = index[3:2]; // index / 4
    assign col = index[1:0]; // index % 4
    
    // Neighbor indices (checking bounds)
    assign top_idx = (row > 0) ? (index - 4) : 15; // Wrap or invalid if 0
    assign left_idx = (col > 0) ? (index - 1) : 15;
    assign bottom_idx = (row < 3) ? (index + 4) : 15;
    assign right_idx = (col < 3) ? (index + 1) : 15;
    
    // Value access
    assign current_val = grid_val[index];
    assign top_val = (row > 0) ? grid_val[top_idx] : -16'sd32768;
    assign left_val = (col > 0) ? grid_val[left_idx] : -16'sd32768;
    assign bottom_val = (row < 3) ? grid_val[bottom_idx] : 16'sd32767;
    assign right_val = (col < 3) ? grid_val[right_idx] : 16'sd32767;

    // Flops for control signals
    reg start_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_reg <= 1'b0;
        end else begin
            if (start) start_reg <= 1'b1;
            if (state == IDLE && start_reg) start_reg <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_counter <= 4'd0;
            temp_result <= 16'd0;
            // Initialize grid_val to 0
            grid_val[0] <= 16'd0; grid_val[1] <= 16'd0; grid_val[2] <= 16'd0; grid_val[3] <= 16'd0;
            grid_val[4] <= 16'd0; grid_val[5] <= 16'd0; grid_val[6] <= 16'd0; grid_val[7] <= 16'd0;
            grid_val[8] <= 16'd0; grid_val[9] <= 16'd0; grid_val[10] <= 16'd0; grid_val[11] <= 16'd0;
            grid_val[12] <= 16'd0; grid_val[13] <= 16'd0; grid_val[14] <= 16'd0; grid_val[15] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    cycle_counter <= 4'd0;
                    temp_result <= 16'd0;
                    if (start_reg) begin
                        // Load inputs (treat 0 as -1 for lower bound init)
                        // We do this sequentially to avoid large comb logic
                        if (index < 16) begin
                            grid_val[index] <= (grid_in[index] == 16'd0) ? 16'sd32767 : grid_in[index];
                            index <= index + 4'd1;
                        end else begin
                            index <= 4'd0;
                            next_state <= CHECK_CONFLICTS;
                            state <= PROPAGATE; // Initial propagation
                        end
                    end
                end

                PROPAGATE: begin
                    // Forward sweep: Top-Left to Bottom-Right
                    // val >= max(top+1, left+1)
                    if (index < 16) begin
                        reg signed [15:0] min_req;
                        min_req = (top_val > left_val) ? top_val : left_val;
                        if (min_req == -16'sd32768) min_req = 16'sd32767; // No constraint
                        
                        if (grid_val[index] < min_req + 16'sd1) begin
                            grid_val[index] <= min_req + 16'sd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        // Reverse sweep: Bottom-Right to Top-Left
                        // val <= min(bottom-1, right-1)
                        if (index > 4'd0) begin
                            index <= index - 4'd1;
                            reg signed [15:0] max_allowed;
                            max_allowed = (bottom_val < right_val) ? bottom_val : right_val;
                            if (max_allowed == 16'sd32767) max_allowed = 16'sd32767; // No constraint
                            
                            if (grid_val[index - 1] > max_allowed - 16'sd1) begin
                                grid_val[index - 1] <= max_allowed - 16'sd1;
                            end
                        end else begin
                            // Finished sweep
                            cycle_counter <= cycle_counter + 4'd1;
                            if (cycle_counter >= 4'd8) begin // Limit iterations
                                state <= CHECK_CONFLICTS;
                                index <= 4'd0;
                            end else begin
                                index <= 4'd0;
                            end
                        end
                    end
                end

                CHECK_CONFLICTS: begin
                    // Check 0 values (unassigned)
                    if (index < 16) begin
                        if (grid_val[index] == 16'd0) begin
                            state <= ERROR_STATE;
                        end else begin
                            // Check Parity of Diagonals
                            // (i,j) vs (i+1, j+1)
                            // (i,j) vs (i+1, j-1)
                            if (row < 3 && col < 3) begin
                                if ((grid_val[index][0] == grid_val[index + 5][0]) && (grid_val[index] == grid_val[index + 5])) begin
                                    // Same value and same parity -> conflict
                                    // Fix: Increment bottom-right
                                    grid_val[index + 5] <= grid_val[index + 5] + 16'sd1;
                                    state <= PROPAGATE; // Re-propagate
                                    next_state <= CHECK_CONFLICTS;
                                    index <= 4'd0;
                                    cycle_counter <= cycle_counter + 4'd1;
                                end else begin
                                    index <= index + 4'd1;
                                end
                            end else if (row < 3 && col > 0) begin
                                if ((grid_val[index][0] == grid_val[index + 3][0]) && (grid_val[index] == grid_val[index + 3])) begin
                                    grid_val[index + 3] <= grid_val[index + 3] + 16'sd1;
                                    state <= PROPAGATE;
                                    next_state <= CHECK_CONFLICTS;
                                    index <= 4'd0;
                                    cycle_counter <= cycle_counter + 4'd1;
                                end else begin
                                    index <= index + 4'd1;
                                end
                            end else begin
                                index <= index + 4'd1;
                            end
                            
                            // Check max cycles in conflict check
                            if (cycle_counter >= 4'd14) state <= ERROR_STATE;
                        end
                    end else begin
                        state <= CALCULATE_SUM;
                        index <= 4'd0;
                        temp_result <= 16'd0;
                    end
                end

                CALCULATE_SUM: begin
                    if (index < 16) begin
                        // Check for overflow or decreasing sequence (final check)
                        if (index > 0) begin
                            if (grid_val[index] <= grid_val[index - 1]) begin
                                // Decreasing or equal detected
                                state <= ERROR_STATE;
                            end else begin
                                temp_result <= temp_result + grid_val[index];
                                index <= index + 4'd1;
                            end
                        end else begin
                            temp_result <= temp_result + grid_val[index];
                            index <= index + 4'd1;
                        end
                    end else begin
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR_STATE: begin
                    result <= 16'hFFFF; // -1 error code
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule