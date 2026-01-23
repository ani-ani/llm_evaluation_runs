module EulerianNumber(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] m_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] INIT      = 3'd2;
    localparam [2:0] NEXT_ROW  = 3'd3;
    localparam [2:0] COMPLETE  = 3'd4;

    reg [2:0] state;
    reg [3:0] current_n;
    reg [3:0] current_m;
    reg [15:0] dp_prev_row [0:7];
    reg [15:0] dp_curr_row [0:7];
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [15:0] temp_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            current_m <= 4'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            temp_value <= 16'd0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                dp_prev_row[i] <= 16'd0;
                dp_curr_row[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Validate inputs
                    if (n_in == 4'd0 || m_in >= n_in) begin
                        result <= 16'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        current_n <= n_in;
                        current_m <= m_in;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize n=0 row
                    dp_prev_row[0] <= 16'd1;
                    integer i;
                    for (i = 1; i < 8; i = i + 1) begin
                        dp_prev_row[i] <= 16'd0;
                    end
                    row_idx <= 4'd1;
                    state <= NEXT_ROW;
                end

                NEXT_ROW: begin
                    // Compute current row from previous row
                    if (col_idx == 4'd0) begin
                        // Base case: a(n, 0) = 1
                        dp_curr_row[0] <= 16'd1;
                        col_idx <= 4'd1;
                    end else if (col_idx < row_idx) begin
                        // Compute a(n, m) = (n-m)*a(n-1, m-1) + (m+1)*a(n-1, m)
                        temp_value <= (row_idx - col_idx) * dp_prev_row[col_idx - 1] + 
                                     (col_idx + 1) * dp_prev_row[col_idx];
                        dp_curr_row[col_idx] <= temp_value;
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        // End of row
                        col_idx <= 4'd0;
                        
                        // Copy current row to previous row
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            dp_prev_row[i] <= dp_curr_row[i];
                        end
                        
                        // Check if we've reached target n
                        if (row_idx == current_n) begin
                            state <= COMPLETE;
                        end else begin
                            row_idx <= row_idx + 4'd1;
                        end
                    end
                end

                COMPLETE: begin
                    result <= dp_prev_row[current_m];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule