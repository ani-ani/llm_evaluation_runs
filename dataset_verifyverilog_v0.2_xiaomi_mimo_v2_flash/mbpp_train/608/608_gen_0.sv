module bell_number (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam INIT = 5'b00010;
    localparam COMPUTE_ROW = 5'b00100;
    localparam COMPUTE_COL = 5'b01000;
    localparam DONE = 5'b10000;

    reg [4:0] current_state, next_state;
    reg [3:0] i, j; // i: row index, j: column index
    reg [3:0] i_reg, j_reg; // Registered indices for next cycle logic
    
    // Bell triangle storage: 9x9 triangular array (rows 0-8, columns 0-8)
    // Using a 2D array declaration (supported in synthesis)
    reg [15:0] bell [0:8][0:8];
    
    // Temporary registers for read and write data to avoid synthesis issues
    reg [15:0] read_val_a;
    reg [15:0] read_val_b;
    reg [15:0] write_val;
    reg [3:0] write_i;
    reg [3:0] write_j;
    reg write_en;

    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            done <= 1'b0;
            result <= 16'd0;
            write_en <= 1'b0;
        end else begin
            // Default values
            write_en <= 1'b0;
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= INIT;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    // Initialize bell[0][0] = 1
                    bell[0][0] <= 16'd1;
                    i <= 4'd1;
                    j <= 4'd0;
                    
                    // Check if n is 0
                    if (n == 4'd0) begin
                        result <= 16'd1;
                        done <= 1'b1;
                        current_state <= IDLE;
                    end else begin
                        current_state <= COMPUTE_ROW;
                    end
                end

                COMPUTE_ROW: begin
                    // Calculate bell[i][0] = bell[i-1][i-1]
                    // bell[i-1][i-1] is available immediately since i-1 row is fully computed
                    bell[i][0] <= bell[i-1][i-1];
                    j <= 4'd1;
                    
                    if (i > n) begin
                        // Computation complete, go to DONE
                        result <= bell[n][0];
                        done <= 1'b1;
                        current_state <= IDLE;
                    end else if (i == 4'd0) begin
                        // Should not happen after INIT check for n=0, but safety
                        current_state <= UPDATE;
                    end else begin
                        current_state <= COMPUTE_COL;
                    end
                end

                COMPUTE_COL: begin
                    // Calculate bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
                    // Both values are available:
                    // - bell[i-1][j-1] from previous row (already computed)
                    // - bell[i][j-1] just computed in previous column of current row
                    bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
                    
                    if (j < i) begin
                        j <= j + 1'b1;
                        current_state <= COMPUTE_COL;
                    end else begin
                        current_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Move to next row
                    i <= i + 1'b1;
                    j <= 4'd0;
                    
                    if (i + 1'b1 > n) begin
                        // After this update, i will be > n, so next state should be DONE
                        // But we need to go to COMPUTE_ROW first to set result properly
                        // Or we can check here and set result
                        result <= bell[n][0];
                        done <= 1'b1;
                        current_state <= IDLE;
                    end else begin
                        current_state <= COMPUTE_ROW;
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule