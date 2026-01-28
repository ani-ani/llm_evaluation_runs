module matrix_sorter (
    input clk,
    input rst_n,
    input start,
    input signed [3:0] matrix_00,
    input signed [3:0] matrix_01,
    input signed [3:0] matrix_02,
    input signed [3:0] matrix_10,
    input signed [3:0] matrix_11,
    input signed [3:0] matrix_12,
    input signed [3:0] matrix_20,
    input signed [3:0] matrix_21,
    input signed [3:0] matrix_22,
    output reg signed [3:0] result [0:8],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_SUMS = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Matrix storage (packed internally for easier manipulation)
    reg signed [3:0] mat [0:8]; // Flat storage: row0:0,1,2; row1:3,4,5; row2:6,7,8
    
    // Row sums (6-bit signed)
    reg signed [5:0] row_sums [0:2];
    
    // Sorting variables
    reg [1:0] sort_iter; // 0,1,2 for 3 rows
    reg [1:0] sort_idx;  // index within iteration
    reg swap_flag;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd7; // Sufficient for operations

    integer i;

    // State transition and registered outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                result[i] <= 4'sd0;
            end
            for (i = 0; i < 9; i = i + 1) begin
                mat[i] <= 4'sd0;
            end
            for (i = 0; i < 3; i = i + 1) begin
                row_sums[i] <= 6'sd0;
            end
            sort_iter <= 2'd0;
            sort_idx <= 2'd0;
            swap_flag <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        // Store input matrix
                        mat[0] <= matrix_00;
                        mat[1] <= matrix_01;
                        mat[2] <= matrix_02;
                        mat[3] <= matrix_10;
                        mat[4] <= matrix_11;
                        mat[5] <= matrix_12;
                        mat[6] <= matrix_20;
                        mat[7] <= matrix_21;
                        mat[8] <= matrix_22;
                        state <= CALC_SUMS;
                    end
                end

                CALC_SUMS: begin
                    // Compute sums for all rows in parallel (combinational logic simulated)
                    row_sums[0] <= matrix_00 + matrix_01 + matrix_02;
                    row_sums[1] <= matrix_10 + matrix_11 + matrix_12;
                    row_sums[2] <= matrix_20 + matrix_21 + matrix_22;
                    sort_iter <= 2'd0;
                    sort_idx <= 2'd0;
                    state <= SORT;
                end

                SORT: begin
                    // Bubble sort logic for 3 rows
                    // Iteration 0: compare rows 0-1, then 1-2
                    // Iteration 1: compare rows 0-1 (row 2 fixed)
                    // Iteration 2: compare rows 0-1 (row 1-2 fixed)
                    // We use a simplified loop: 2 passes over 3 elements
                    
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Compare and swap logic
                    if (sort_iter < 2'd2) begin
                        // Inner loop index
                        if (sort_idx < 2'd2) begin
                            // Compare row sums
                            if (row_sums[sort_idx] > row_sums[sort_idx + 1]) begin
                                // Swap sums
                                row_sums[sort_idx] <= row_sums[sort_idx + 1];
                                row_sums[sort_idx + 1] <= row_sums[sort_idx];
                                
                                // Swap rows in mat array
                                // Row sort_idx: indices {sort_idx*3, sort_idx*3+1, sort_idx*3+2}
                                // Row sort_idx+1: indices {(sort_idx+1)*3, ...}
                                mat[sort_idx*3]     <= mat[(sort_idx+1)*3];
                                mat[sort_idx*3+1]   <= mat[(sort_idx+1)*3+1];
                                mat[sort_idx*3+2]   <= mat[(sort_idx+1)*3+2];
                                
                                mat[(sort_idx+1)*3]   <= mat[sort_idx*3];
                                mat[(sort_idx+1)*3+1] <= mat[sort_idx*3+1];
                                mat[(sort_idx+1)*3+2] <= mat[sort_idx*3+2];
                            end
                            sort_idx <= sort_idx + 2'd1;
                        end else begin
                            // End of inner loop
                            sort_idx <= 2'd0;
                            sort_iter <= sort_iter + 2'd1;
                        end
                    end else begin
                        // Sorting complete
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Pack the sorted matrix into result
                    // Result[0:2] = Row 0, Result[3:5] = Row 1, Result[6:8] = Row 2
                    result[0] <= mat[0];
                    result[1] <= mat[1];
                    result[2] <= mat[2];
                    result[3] <= mat[3];
                    result[4] <= mat[4];
                    result[5] <= mat[5];
                    result[6] <= mat[6];
                    result[7] <= mat[7];
                    result[8] <= mat[8];
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule