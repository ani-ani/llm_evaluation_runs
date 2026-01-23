module grid_computation (
    input clk,
    input rst_n,
    input start,
    input [3:0] x,
    input [3:0] y,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 1000000007;
    localparam IDLE = 3'b000;
    localparam COMPUTE_ROW = 3'b001;
    localparam COMPUTE_CELL = 3'b010;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;

    // Row and cell counters
    reg [3:0] current_row = 0;
    reg [3:0] current_col = 0;

    // Current and previous row storage (16-bit each)
    reg [15:0] current_row_data [0:15];
    reg [15:0] prev_row_data [0:15];

    // Temporary storage for computation
    reg [31:0] temp_sum;

    // Modulo function using subtraction
    function [31:0] mod_op;
        input [31:0] val;
        begin
            while (val >= MOD) begin
                val = val - MOD;
            end
            mod_op = val;
        end
    endfunction

    // Initialize base cases
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_row <= 0;
            current_col <= 0;
            done <= 0;
            result <= 0;

            // Initialize base cases
            prev_row_data[0] <= 0;  // F[0,0] = 0
            prev_row_data[1] <= 1;  // F[0,1] = 1
            for (integer i = 2; i <= 15; i = i + 1) begin
                prev_row_data[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE_ROW;
                        current_row <= 0;
                        current_col <= 0;
                        done <= 0;
                    end
                end

                COMPUTE_ROW: begin
                    if (current_row == 0) begin
                        // Compute row 0 (Fibonacci sequence)
                        if (current_col == 0) begin
                            current_row_data[0] <= 0;  // F[0,0] = 0
                            current_col <= 1;
                        end else if (current_col == 1) begin
                            current_row_data[1] <= 1;  // F[0,1] = 1
                            current_col <= 2;
                        end else if (current_col <= 15) begin
                            temp_sum = prev_row_data[current_col-1] + prev_row_data[current_col-2];
                            current_row_data[current_col] <= mod_op(temp_sum);
                            current_col <= current_col + 1;
                        end

                        if (current_col > 15) begin
                            // Copy current row to previous row for next iteration
                            for (integer i = 0; i <= 15; i = i + 1) begin
                                prev_row_data[i] <= current_row_data[i];
                            end
                            current_row <= current_row + 1;
                            current_col <= 0;
                        end
                    end else if (current_row >= 1 && current_row <= 15) begin
                        // Compute row i (Fibonacci for first column, then grid formula)
                        if (current_col == 0) begin
                            if (current_row == 1) begin
                                current_row_data[0] <= 1;  // F[1,0] = 1
                            end else begin
                                temp_sum = prev_row_data[0] + (current_row == 2 ? 0 : prev_row_data[0] - (current_row == 3 ? 1 : prev_row_data[0] - ...));
                                // Simplified Fibonacci for first column
                                temp_sum = prev_row_data[0] + (current_row >= 2 ? (current_row == 2 ? 1 : prev_row_data[0] - (current_row == 3 ? 1 : prev_row_data[0] - ...)) : 0);
                                // Correct Fibonacci implementation for first column
                                if (current_row == 1) begin
                                    current_row_data[0] <= 1;
                                end else if (current_row == 2) begin
                                    current_row_data[0] <= mod_op(prev_row_data[0] + 1);
                                end else begin
                                    temp_sum = prev_row_data[0] + (current_row_data[0] - prev_row_data[0]);
                                    current_row_data[0] <= mod_op(temp_sum);
                                end
                            end
                            current_col <= 1;
                        end else if (current_col >= 1 && current_col <= 15) begin
                            temp_sum = prev_row_data[current_col] + current_row_data[current_col-1];
                            current_row_data[current_col] <= mod_op(temp_sum);
                            current_col <= current_col + 1;
                        end

                        if (current_col > 15) begin
                            // Copy current row to previous row for next iteration
                            for (integer i = 0; i <= 15; i = i + 1) begin
                                prev_row_data[i] <= current_row_data[i];
                            end
                            current_row <= current_row + 1;
                            current_col <= 0;
                        end
                    end

                    if (current_row > 15) begin
                        state <= DONE;
                    end
                end

                COMPUTE_CELL: begin
                    // Not used in this implementation, handled within COMPUTE_ROW
                    state <= COMPUTE_ROW;
                end

                DONE: begin
                    done <= 1;
                    result <= current_row_data[y];
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule