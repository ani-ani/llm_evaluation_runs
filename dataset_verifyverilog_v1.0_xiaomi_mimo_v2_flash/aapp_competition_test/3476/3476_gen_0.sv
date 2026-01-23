module matrix_max_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] matrix_in [0:7][0:7],
    output reg signed [15:0] max_sum,
    output reg [7:0] row_mask,
    output reg [7:0] col_mask,
    output reg [7:0] op_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] ROW_ITER = 3'd2;
    localparam [2:0] COMPUTE_SUM = 3'd3;
    localparam [2:0] COL_GREEDY = 3'd4;
    localparam [2:0] UPDATE_BEST = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] row_iter;          // Row iteration counter (0-255)
    reg [3:0] col_iter;          // Column iteration counter (0-7)
    reg [7:0] row_pattern;       // Current row negation pattern
    reg signed [15:0] current_sum;  // Sum for current pattern
    reg signed [15:0] col_sum [0:7];  // Column sums after row negations
    reg [7:0] temp_col_mask;     // Temporary column mask for greedy
    reg [7:0] temp_row_mask;     // Temporary row mask
    reg [7:0] temp_op_count;     // Temporary operation count
    reg signed [15:0] temp_max_sum;  // Best sum found so far
    reg [7:0] best_row_mask;     // Best row mask found
    reg [7:0] best_col_mask;     // Best col mask found
    reg [7:0] best_op_count;     // Best op count found
    reg [3:0] i, j, k;           // Loop indices
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Matrix storage
    reg signed [7:0] stored_matrix [0:7][0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_sum <= 16'sd0;
            row_mask <= 8'd0;
            col_mask <= 8'd0;
            op_count <= 8'd0;
            done <= 1'b0;
            row_iter <= 8'd0;
            col_iter <= 4'd0;
            row_pattern <= 8'd0;
            current_sum <= 16'sd0;
            temp_col_mask <= 8'd0;
            temp_row_mask <= 8'd0;
            temp_op_count <= 8'd0;
            temp_max_sum <= 16'sd0;
            best_row_mask <= 8'd0;
            best_col_mask <= 8'd0;
            best_op_count <= 8'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                col_sum[i] <= 16'sd0;
                for (j = 0; j < 8; j = j + 1) begin
                    stored_matrix[i][j] <= 8'sd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Latch matrix into storage
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            stored_matrix[i][j] <= matrix_in[i][j];
                        end
                    end
                    state <= ROW_ITER;
                end

                ROW_ITER: begin
                    row_pattern <= row_iter;
                    // Initialize temp values for this iteration
                    temp_max_sum <= 16'sd0;
                    temp_row_mask <= row_pattern;
                    temp_col_mask <= 8'd0;
                    temp_op_count <= 8'd0;
                    // Count row negations for op_count
                    for (k = 0; k < 8; k = k + 1) begin
                        if (row_pattern[k]) begin
                            temp_op_count <= temp_op_count + 8'd1;
                        end
                    end
                    // Reset column sums
                    for (k = 0; k < 8; k = k + 1) begin
                        col_sum[k] <= 16'sd0;
                    end
                    col_iter <= 4'd0;
                    state <= COMPUTE_SUM;
                end

                COMPUTE_SUM: begin
                    // Compute column sums with current row pattern
                    for (j = 0; j < 8; j = j + 1) begin
                        col_sum[j] <= 16'sd0;
                    end
                    current_sum <= 16'sd0;
                    col_iter <= 4'd0;
                    state <= COL_GREEDY;
                end

                COL_GREEDY: begin
                    // Greedy column selection
                    if (col_iter < 4'd8) begin
                        // Compute this column's sum
                        reg signed [15:0] col_val;
                        col_val = 16'sd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (row_pattern[i]) begin
                                col_val <= col_val - $signed(stored_matrix[i][col_iter]);
                            end else begin
                                col_val <= col_val + $signed(stored_matrix[i][col_iter]);
                            end
                        end
                        col_sum[col_iter] <= col_val;
                        
                        if (col_val < 16'sd0) begin
                            temp_col_mask[col_iter] <= 1'b1;
                            temp_op_count <= temp_op_count + 8'd1;
                            current_sum <= current_sum - col_val;
                        end else begin
                            temp_col_mask[col_iter] <= 1'b0;
                            current_sum <= current_sum + col_val;
                        end
                        col_iter <= col_iter + 4'd1;
                    end else begin
                        state <= UPDATE_BEST;
                    end
                end

                UPDATE_BEST: begin
                    // Update best if current is better
                    if (current_sum > temp_max_sum) begin
                        temp_max_sum <= current_sum;
                        best_row_mask <= temp_row_mask;
                        best_col_mask <= temp_col_mask;
                        best_op_count <= temp_op_count;
                    end
                    
                    // Next row iteration
                    if (row_iter < 8'd255) begin
                        row_iter <= row_iter + 8'd1;
                        state <= ROW_ITER;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    max_sum <= temp_max_sum;
                    row_mask <= best_row_mask;
                    col_mask <= best_col_mask;
                    op_count <= best_op_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule