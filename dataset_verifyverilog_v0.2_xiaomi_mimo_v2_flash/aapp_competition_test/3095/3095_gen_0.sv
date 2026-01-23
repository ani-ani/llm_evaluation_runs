module extremely_cool_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] rows,
    input wire [3:0] cols,
    input wire [7:0] matrix_data [0:63],
    output reg is_cool,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECKING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] r, next_r;
    reg [3:0] c, next_c;
    reg cool_reg, next_cool;
    reg done_reg, next_done;

    // Combinational logic for matrix values and condition
    wire [7:0] a, b, c_val, d;
    wire [8:0] sum_ad, sum_bc; // 9-bit for addition to prevent overflow

    // Read matrix data based on current row and column
    assign a = matrix_data[r * 8 + c];
    assign b = matrix_data[r * 8 + c + 1];
    assign c_val = matrix_data[(r + 1) * 8 + c];
    assign d = matrix_data[(r + 1) * 8 + c + 1];

    // Signed addition: a + d <= b + c_val
    // Equivalent to: (a + d) - (b + c_val) <= 0
    assign sum_ad = $signed(a) + $signed(d);
    assign sum_bc = $signed(b) + $signed(c_val);

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_r = r;
        next_c = c;
        next_cool = cool_reg;
        next_done = done_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    if (rows < 2 || cols < 2) begin
                        // Condition for immediate completion (empty or 1D submatrix is valid)
                        next_state = DONE;
                        next_cool = 1'b1;
                        next_done = 1'b1;
                    end else begin
                        next_state = CHECKING;
                        next_r = 0;
                        next_c = 0;
                        next_cool = 1'b1;
                        next_done = 1'b0;
                    end
                end
            end

            CHECKING: begin
                // Check current condition
                if (sum_ad > sum_bc) begin
                    next_cool = 1'b0;
                end

                // Update indices
                if (c < cols - 2) begin
                    next_c = c + 1;
                end else begin
                    next_c = 0;
                    if (r < rows - 2) begin
                        next_r = r + 1;
                    end else begin
                        // All checks done
                        next_state = DONE;
                        next_done = 1'b1;
                    end
                end
            end

            DONE: begin
                // Stay in DONE state
                // next_state = DONE; 
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r <= 0;
            c <= 0;
            is_cool <= 1'b1;
            done <= 1'b0;
        end else begin
            state <= next_state;
            r <= next_r;
            c <= next_c;
            is_cool <= next_cool;
            done <= next_done;
        end
    end

    // Internal regs for combinational logic triggers (optional but good for clarity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cool_reg <= 1'b1;
            done_reg <= 1'b0;
        end else begin
            cool_reg <= next_cool;
            done_reg <= next_done;
        end
    end

endmodule