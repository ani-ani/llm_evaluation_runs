module max_path_average(
    input clk,
    input rst_n,
    input start,
    input [63:0] cost,
    input valid_input,
    output reg [15:0] result,
    output reg done,
    output reg overflow
);

    // Parameters
    localparam [3:0] N = 8'd8;
    localparam [7:0] DATA_WIDTH = 8'd8;
    localparam [7:0] DP_WIDTH = 8'd16;
    localparam [7:0] OUT_WIDTH = 8'd16;
    localparam [7:0] NUM_PATH_CELLS = 8'd15; // 2*N - 1
    localparam [7:0] FIXED_SHIFT = 8'd8; // Q8.8 format
    localparam [15:0] DIVISOR = 16'd15; // 2*N - 1
    localparam [15:0] SHIFT_FACTOR = 16'd256; // 2^8 for Q8.8
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_ROW0 = 3'd1;
    localparam [2:0] LOAD_ROWS = 3'd2;
    localparam [2:0] COMPUTE_AVG = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] row_idx;
    reg [7:0] col_idx;
    reg [7:0] cycle_count;
    reg [15:0] dp_regs [0:7]; // DP values for current row (8 cells max)
    reg [15:0] dp_prev [0:7]; // Previous row DP values
    reg [7:0] current_cost [0:7]; // Current row costs
    reg [15:0] final_sum;
    reg [15:0] overflow_detect;
    reg processing_done;
    
    // Temporary variables for computation
    reg [15:0] max_val;
    reg [15:0] temp_sum;
    reg [15:0] division_temp;
    reg [23:0] mult_temp; // 16x8 = 24 bits
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            overflow <= 1'b0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            cycle_count <= 8'd0;
            final_sum <= 16'd0;
            processing_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                dp_regs[i] <= 16'd0;
                dp_prev[i] <= 16'd0;
                current_cost[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    cycle_count <= 8'd0;
                    row_idx <= 8'd0;
                    col_idx <= 8'd0;
                    if (start && valid_input) begin
                        state <= LOAD_ROW0;
                        // Unpack first row costs
                        current_cost[0] <= cost[7:0];
                        current_cost[1] <= cost[15:8];
                        current_cost[2] <= cost[23:16];
                        current_cost[3] <= cost[31:24];
                        current_cost[4] <= cost[39:32];
                        current_cost[5] <= cost[47:40];
                        current_cost[6] <= cost[55:48];
                        current_cost[7] <= cost[63:56];
                    end
                end
                
                LOAD_ROW0: begin
                    // Compute first row cumulative sums
                    if (col_idx < N) begin
                        if (col_idx == 8'd0) begin
                            // First cell: just cost
                            dp_regs[0] <= {{8{current_cost[0][7]}}, current_cost[0]}; // Sign extend to 16 bits
                            overflow_detect <= {{8{current_cost[0][7]}}, current_cost[0]};
                        end else begin
                            // Subsequent cells: previous + current
                            temp_sum <= dp_regs[col_idx - 8'd1] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]};
                            overflow_detect <= dp_regs[col_idx - 8'd1] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]};
                        end
                        col_idx <= col_idx + 8'd1;
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        // Move temp_sum to dp_regs and check overflow
                        if (col_idx > 8'd0) begin
                            dp_regs[col_idx - 8'd1] <= temp_sum;
                            // Check overflow (signed 16-bit range)
                            if (temp_sum > 16'sd32767 || temp_sum < 16'sd32768) begin
                                overflow <= 1'b1;
                            end
                        end
                        col_idx <= 8'd0;
                        row_idx <= 8'd1;
                        // Save current row as previous
                        for (i = 0; i < 8; i = i + 1) begin
                            dp_prev[i] <= dp_regs[i];
                        end
                        state <= LOAD_ROWS;
                    end
                end
                
                LOAD_ROWS: begin
                    if (row_idx < N) begin
                        if (col_idx < N) begin
                            // Unpack current cost
                            if (row_idx == 8'd1 && col_idx == 8'd0) begin
                                // Unpack row 1 costs
                                current_cost[0] <= cost[7:0];
                                current_cost[1] <= cost[15:8];
                                current_cost[2] <= cost[23:16];
                                current_cost[3] <= cost[31:24];
                                current_cost[4] <= cost[39:32];
                                current_cost[5] <= cost[47:40];
                                current_cost[6] <= cost[55:48];
                                current_cost[7] <= cost[63:56];
                            end
                            
                            // Compute DP value
                            if (row_idx == 8'd0) begin
                                // First row handled in LOAD_ROW0
                            end else if (col_idx == 8'd0) begin
                                // First column: only from top
                                dp_regs[0] <= dp_prev[0] + {{8{current_cost[0][7]}}, current_cost[0]};
                                overflow_detect <= dp_prev[0] + {{8{current_cost[0][7]}}, current_cost[0]};
                            end else begin
                                // Max of top and left, plus current cost
                                if (dp_prev[col_idx] > dp_regs[col_idx - 8'd1]) begin
                                    max_val <= dp_prev[col_idx];
                                end else begin
                                    max_val <= dp_regs[col_idx - 8'd1];
                                end
                                temp_sum <= (dp_prev[col_idx] > dp_regs[col_idx - 8'd1]) ? 
                                            (dp_prev[col_idx] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]}) :
                                            (dp_regs[col_idx - 8'd1] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]});
                                overflow_detect <= (dp_prev[col_idx] > dp_regs[col_idx - 8'd1]) ? 
                                                    (dp_prev[col_idx] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]}) :
                                                    (dp_regs[col_idx - 8'd1] + {{8{current_cost[col_idx][7]}}, current_cost[col_idx]});
                            end
                            
                            col_idx <= col_idx + 8'd1;
                            cycle_count <= cycle_count + 8'd1;
                        end else begin
                            // Row complete, save result
                            if (row_idx > 8'd0 && col_idx > 8'd0) begin
                                if (col_idx <= N) begin
                                    dp_regs[col_idx - 8'd1] <= temp_sum;
                                    if (temp_sum > 16'sd32767 || temp_sum < 16'sd32768) begin
                                        overflow <= 1'b1;
                                    end
                                end
                            end
                            col_idx <= 8'd0;
                            row_idx <= row_idx + 8'd1;
                            // Save current row as previous for next iteration
                            for (i = 0; i < 8; i = i + 1) begin
                                dp_prev[i] <= dp_regs[i];
                            end
                            // Unpack next row costs if not last row
                            if (row_idx < N - 1) begin
                                current_cost[0] <= cost[7:0];
                                current_cost[1] <= cost[15:8];
                                current_cost[2] <= cost[23:16];
                                current_cost[3] <= cost[31:24];
                                current_cost[4] <= cost[39:32];
                                current_cost[5] <= cost[47:40];
                                current_cost[6] <= cost[55:48];
                                current_cost[7] <= cost[63:56];
                            end
                        end
                    end else begin
                        // Grid processing complete, get final sum
                        final_sum <= dp_regs[7];
                        state <= COMPUTE_AVG;
                    end
                end
                
                COMPUTE_AVG: begin
                    // Compute: sum * 256 / 15
                    // Fixed-point multiplication
                    mult_temp <= final_sum * SHIFT_FACTOR; // 16-bit * 16-bit = 32-bit, but we need 24-bit
                    division_temp <= (final_sum * SHIFT_FACTOR) / DIVISOR;
                    result <= (final_sum * SHIFT_FACTOR) / DIVISOR;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    row_idx <= 8'd0;
                    col_idx <= 8'd0;
                    processing_done <= 1'b1;
                    for (i = 0; i < 8; i = i + 1) begin
                        dp_regs[i] <= 16'd0;
                        dp_prev[i] <= 16'd0;
                        current_cost[i] <= 8'd0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule