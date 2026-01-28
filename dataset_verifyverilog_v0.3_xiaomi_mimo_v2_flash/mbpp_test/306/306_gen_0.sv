module MaxSumIncreasingSubseq(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [2:0] target_index,
    input [2:0] target_k,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT_DP       = 3'd1;
    localparam [2:0] COMPUTE_ROWS  = 3'd2;
    localparam [2:0] OUTPUT_RESULT = 3'd3;
    localparam [2:0] FINISH        = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] i_reg, j_reg;           // Row and column indices
    reg [2:0] row_idx, col_idx;       // For storing current compute indices
    reg [15:0] dp_table [0:7][0:7];   // 8x8 DP table (packed as 2D array)
    reg [7:0] arr_reg [0:7];          // Input array storage
    reg [15:0] temp_val1, temp_val2;
    reg [15:0] max_val;
    reg compute_done;
    
    // Loop control
    reg [2:0] loop_i, loop_j;
    reg [2:0] max_i, max_j;

    // Control signals
    reg load_inputs;
    reg compute_init_row;
    reg compute_row;
    reg store_result;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    integer k;  // Loop variable for initialization

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            loop_i <= 3'd0;
            loop_j <= 3'd0;
            max_i <= 3'd0;
            max_j <= 3'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            temp_val1 <= 16'd0;
            temp_val2 <= 16'd0;
            max_val <= 16'd0;
            compute_done <= 1'b0;
            load_inputs <= 1'b0;
            compute_init_row <= 1'b0;
            compute_row <= 1'b0;
            store_result <= 1'b0;
            // Initialize DP table
            for (k = 0; k < 8; k = k + 1) begin
                dp_table[k][0] <= 16'd0;
                dp_table[k][1] <= 16'd0;
                dp_table[k][2] <= 16'd0;
                dp_table[k][3] <= 16'd0;
                dp_table[k][4] <= 16'd0;
                dp_table[k][5] <= 16'd0;
                dp_table[k][6] <= 16'd0;
                dp_table[k][7] <= 16'd0;
            end
            // Initialize input array
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0;
            arr_reg[5] <= 8'd0;
            arr_reg[6] <= 8'd0;
            arr_reg[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            // Control signals
            if (load_inputs) begin
                arr_reg[0] <= arr_0;
                arr_reg[1] <= arr_1;
                arr_reg[2] <= arr_2;
                arr_reg[3] <= arr_3;
                arr_reg[4] <= arr_4;
                arr_reg[5] <= arr_5;
                arr_reg[6] <= arr_6;
                arr_reg[7] <= arr_7;
            end
            
            // Initialize row 0 of DP table
            if (compute_init_row) begin
                if (j_reg == 3'd0) begin
                    dp_table[0][0] <= 16'd0;  // Base case
                end else begin
                    if (arr_reg[j_reg] > arr_reg[0]) begin
                        dp_table[0][j_reg] <= {8'd0, arr_reg[j_reg]} + {8'd0, arr_reg[0]};
                    end else begin
                        dp_table[0][j_reg] <= {8'd0, arr_reg[j_reg]};
                    end
                end
            end
            
            // Compute other rows
            if (compute_row) begin
                if (row_idx == 3'd0) begin
                    // Row 0 is already computed, move to next
                end else begin
                    if (col_idx == 3'd0) begin
                        // Diagonal element
                        dp_table[row_idx][col_idx] <= 16'd0;
                    end else if (col_idx <= row_idx) begin
                        // Copy from previous row (i >= j case)
                        dp_table[row_idx][col_idx] <= dp_table[row_idx - 3'd1][col_idx];
                    end else begin
                        // col_idx > row_idx
                        if (arr_reg[col_idx] > arr_reg[row_idx]) begin
                            // arr[j] > arr[i] and j > i
                            temp_val1 <= dp_table[row_idx - 3'd1][row_idx] + {8'd0, arr_reg[col_idx]};
                            temp_val2 <= dp_table[row_idx - 3'd1][col_idx];
                            
                            // Compute max in same cycle
                            if (dp_table[row_idx - 3'd1][row_idx] + {8'd0, arr_reg[col_idx]} >= dp_table[row_idx - 3'd1][col_idx]) begin
                                dp_table[row_idx][col_idx] <= dp_table[row_idx - 3'd1][row_idx] + {8'd0, arr_reg[col_idx]};
                            end else begin
                                dp_table[row_idx][col_idx] <= dp_table[row_idx - 3'd1][col_idx];
                            end
                        end else begin
                            dp_table[row_idx][col_idx] <= dp_table[row_idx - 3'd1][col_idx];
                        end
                    end
                end
            end
            
            // Store result
            if (store_result) begin
                result <= dp_table[target_index][target_k];
            end
            
            // Update indices
            if (compute_init_row || compute_row) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            // Reset cycle count when done
            if (state == FINISH) begin
                cycle_count <= 8'd0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        load_inputs = 1'b0;
        compute_init_row = 1'b0;
        compute_row = 1'b0;
        store_result = 1'b0;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = INIT_DP;
                    load_inputs = 1'b1;
                end
            end
            
            INIT_DP: begin
                done = 1'b0;
                if (j_reg < 3'd8) begin
                    compute_init_row = 1'b1;
                    // Advance j
                end else begin
                    j_reg = 3'd0;
                    next_state = COMPUTE_ROWS;
                    i_reg = 3'd1;  // Start from row 1
                    j_reg = 3'd0;  // Start from column 0
                end
            end
            
            COMPUTE_ROWS: begin
                done = 1'b0;
                if (i_reg < 3'd8 && cycle_count < MAX_CYCLES) begin
                    compute_row = 1'b1;
                    row_idx = i_reg;
                    col_idx = j_reg;
                    
                    // Advance column
                    if (j_reg < 3'd7) begin
                        j_reg = j_reg + 3'd1;
                    end else begin
                        // Column done, move to next row
                        j_reg = 3'd0;
                        i_reg = i_reg + 3'd1;
                    end
                end else begin
                    // Either all rows computed or timeout
                    next_state = OUTPUT_RESULT;
                end
            end
            
            OUTPUT_RESULT: begin
                done = 1'b0;
                store_result = 1'b1;
                next_state = FINISH;
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                done = 1'b0;
                next_state = IDLE;
            end
        endcase
        
        // Handle index increments for INIT_DP state specifically
        if (state == INIT_DP && !compute_init_row) begin
            j_reg = j_reg + 3'd1;
        end
    end

endmodule