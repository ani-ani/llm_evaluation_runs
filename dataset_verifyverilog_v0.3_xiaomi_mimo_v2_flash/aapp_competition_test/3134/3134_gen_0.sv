module matrix_recovery (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [7:0] row_parity,
    input [7:0] col_parity,
    output reg [7:0] matrix_out [0:7],
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] INITIALIZE = 3'd2;
    localparam [2:0] FIX_PARITY = 3'd3;
    localparam [2:0] DONE = 3'd4;
    localparam [2:0] ERROR_STATE = 3'd5;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] row_idx;
    reg [2:0] col_idx;
    reg [7:0] matrix [0:7];
    reg [7:0] row_parity_check;
    reg [7:0] col_parity_check;
    reg [2:0] proc_row;
    reg [2:0] proc_col;
    
    // Helper signals
    wire [7:0] row_parity_mask;
    wire [7:0] col_parity_mask;
    
    assign row_parity_mask = (8'hFF >> (8 - n));
    assign col_parity_mask = (8'hFF >> (8 - m));
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            proc_row <= 3'd0;
            proc_col <= 3'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                // Check XOR condition
                if ((^row_parity) != (^col_parity)) begin
                    next_state = ERROR_STATE;
                end else begin
                    next_state = INITIALIZE;
                end
            end
            
            INITIALIZE: begin
                if (row_idx < n) begin
                    next_state = INITIALIZE;
                end else begin
                    next_state = FIX_PARITY;
                end
            end
            
            FIX_PARITY: begin
                if (proc_row < n && proc_col < m) begin
                    next_state = FIX_PARITY;
                end else begin
                    // Check if parities match
                    if (((row_parity_check & row_parity_mask) == (row_parity & row_parity_mask)) &&
                        ((col_parity_check & col_parity_mask) == (col_parity & col_parity_mask))) begin
                        next_state = DONE;
                    end else begin
                        next_state = ERROR_STATE;
                    end
                end
            end
            
            DONE, ERROR_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            done <= 1'b0;
            error <= 1'b0;
            row_parity_check <= 8'd0;
            col_parity_check <= 8'd0;
            // Initialize matrix
            matrix[0] <= 8'd0;
            matrix[1] <= 8'd0;
            matrix[2] <= 8'd0;
            matrix[3] <= 8'd0;
            matrix[4] <= 8'd0;
            matrix[5] <= 8'd0;
            matrix[6] <= 8'd0;
            matrix[7] <= 8'd0;
            matrix_out[0] <= 8'd0;
            matrix_out[1] <= 8'd0;
            matrix_out[2] <= 8'd0;
            matrix_out[3] <= 8'd0;
            matrix_out[4] <= 8'd0;
            matrix_out[5] <= 8'd0;
            matrix_out[6] <= 8'd0;
            matrix_out[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    proc_row <= 3'd0;
                    proc_col <= 3'd0;
                end
                
                CHECK: begin
                    row_parity_check <= 8'd0;
                    col_parity_check <= 8'd0;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    proc_row <= 3'd0;
                    proc_col <= 3'd0;
                end
                
                INITIALIZE: begin
                    if (row_idx < n) begin
                        // Set all bits in current row to 1
                        matrix[row_idx] <= 8'hFF;
                        row_idx <= row_idx + 3'd1;
                    end
                end
                
                FIX_PARITY: begin
                    if (proc_row < n && proc_col < m) begin
                        // Calculate current row and column (start from bottom-right)
                        if (matrix[n - 1 - proc_row][m - 1 - proc_col] == 1'b1) begin
                            // Check if this bit needs to be flipped
                            if ((row_parity_check[proc_row] != row_parity[proc_row]) &&
                                (col_parity_check[proc_col] != col_parity[proc_col])) begin
                                // Flip bit to 0
                                matrix[n - 1 - proc_row][m - 1 - proc_col] <= 1'b0;
                                // Update parity checks
                                row_parity_check[proc_row] <= ~row_parity_check[proc_row];
                                col_parity_check[proc_col] <= ~col_parity_check[proc_col];
                            end
                        end
                        
                        // Move to next position
                        if (proc_col < m - 3'd1) begin
                            proc_col <= proc_col + 3'd1;
                        end else begin
                            proc_col <= 3'd0;
                            proc_row <= proc_row + 3'd1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    error <= 1'b0;
                    // Copy matrix to output
                    matrix_out[0] <= matrix[0];
                    matrix_out[1] <= matrix[1];
                    matrix_out[2] <= matrix[2];
                    matrix_out[3] <= matrix[3];
                    matrix_out[4] <= matrix[4];
                    matrix_out[5] <= matrix[5];
                    matrix_out[6] <= matrix[6];
                    matrix_out[7] <= matrix[7];
                end
                
                ERROR_STATE: begin
                    done <= 1'b1;
                    error <= 1'b1;
                    // Output all zeros
                    matrix_out[0] <= 8'd0;
                    matrix_out[1] <= 8'd0;
                    matrix_out[2] <= 8'd0;
                    matrix_out[3] <= 8'd0;
                    matrix_out[4] <= 8'd0;
                    matrix_out[5] <= 8'd0;
                    matrix_out[6] <= 8'd0;
                    matrix_out[7] <= 8'd0;
                end
            endcase
        end
    end
endmodule