module matrix_max_sum(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] matrix_in [0:7][0:7],
    output reg signed [15:0] max_sum,
    output reg [7:0] row_mask,
    output reg [7:0] col_mask,
    output reg [7:0] op_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ROW = 3'd1;
    localparam [2:0] COMPUTE_COL = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] row_pattern;
    reg [7:0] col_pattern;
    reg [7:0] current_row;
    reg [7:0] current_col;
    reg signed [15:0] current_sum;
    reg signed [15:0] best_sum;
    reg [7:0] best_row_mask;
    reg [7:0] best_col_mask;
    reg [7:0] best_op_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_pattern <= 8'd0;
            col_pattern <= 8'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
            current_sum <= 16'd0;
            best_sum <= 16'd0;
            best_row_mask <= 8'd0;
            best_col_mask <= 8'd0;
            best_op_count <= 8'd0;
            max_sum <= 16'd0;
            row_mask <= 8'd0;
            col_mask <= 8'd0;
            op_count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_ROW;
                        row_pattern <= 8'd0;
                        current_row <= 8'd0;
                        current_sum <= 16'd0;
                        best_sum <= 16'd0;
                        best_row_mask <= 8'd0;
                        best_col_mask <= 8'd0;
                        best_op_count <= 8'd0;
                    end
                end

                COMPUTE_ROW: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute row sum with current row pattern
                    if (current_row < 8'd8) begin
                        if (row_pattern[current_row]) begin
                            current_sum <= current_sum - matrix_in[current_row][current_col];
                        end else begin
                            current_sum <= current_sum + matrix_in[current_row][current_col];
                        end
                        
                        if (current_col < 7'd7) begin
                            current_col <= current_col + 8'd1;
                        end else begin
                            current_col <= 8'd0;
                            current_row <= current_row + 8'd1;
                        end
                    end else begin
                        // All rows processed, move to column computation
                        state <= COMPUTE_COL;
                        current_col <= 8'd0;
                        col_pattern <= 8'd0;
                    end
                end

                COMPUTE_COL: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Greedy column selection
                    if (current_col < 8'd8) begin
                        reg signed [15:0] col_sum;
                        integer j;
                        
                        // Calculate column sum
                        col_sum = 16'd0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (row_pattern[j]) begin
                                col_sum = col_sum - matrix_in[j][current_col];
                            end else begin
                                col_sum = col_sum + matrix_in[j][current_col];
                            end
                        end
                        
                        // Negate column if sum is negative
                        if (col_sum < 16'd0) begin
                            col_pattern[current_col] <= 1'b1;
                        end else begin
                            col_pattern[current_col] <= 1'b0;
                        end
                        
                        current_col <= current_col + 8'd1;
                    end else begin
                        // All columns processed, evaluate this pattern
                        reg [7:0] temp_op_count;
                        integer i;
                        
                        // Count operations (rows + columns to negate)
                        temp_op_count = 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (row_pattern[i]) temp_op_count = temp_op_count + 8'd1;
                            if (col_pattern[i]) temp_op_count = temp_op_count + 8'd1;
                        end
                        
                        // Update best if current is better
                        if (current_sum > best_sum || (current_sum == best_sum && temp_op_count < best_op_count)) begin
                            best_sum <= current_sum;
                            best_row_mask <= row_pattern;
                            best_col_mask <= col_pattern;
                            best_op_count <= temp_op_count;
                        end
                        
                        // Move to next row pattern
                        if (row_pattern < 8'd255) begin
                            state <= COMPUTE_ROW;
                            row_pattern <= row_pattern + 8'd1;
                            current_row <= 8'd0;
                            current_col <= 8'd0;
                            current_sum <= 16'd0;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    max_sum <= best_sum;
                    row_mask <= best_row_mask;
                    col_mask <= best_col_mask;
                    op_count <= best_op_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule