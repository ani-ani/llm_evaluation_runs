module perfect_square_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [15:0] i;  // Current divisor
    reg [31:0] i_sq;  // i*i (32-bit to prevent overflow)
    reg [15:0] quotient;  // num_in / i
    reg [15:0] remainder;  // num_in % i
    reg is_square;  // Intermediate result
    reg [7:0] iter_count;  // Prevent infinite loops
    localparam [7:0] MAX_ITER = 8'd256;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 16'd0;
            i_sq <= 32'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            is_square <= 1'b0;
            iter_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTING;
                        i <= 16'd1;
                        iter_count <= 8'd0;
                        is_square <= 1'b0;
                    end
                end

                COMPUTING: begin
                    iter_count <= iter_count + 8'd1;
                    i_sq <= $unsigned(i) * $unsigned(i);  // 16x16 = 32-bit

                    // Check if i*i > num_in
                    if (i_sq > num_in || iter_count >= MAX_ITER) begin
                        state <= DONE;
                        is_square <= 1'b0;
                    end else begin
                        // Compute quotient and remainder
                        quotient <= num_in / i;
                        remainder <= num_in % i;

                        // Check if perfect square
                        if (remainder == 16'd0 && quotient == i) begin
                            state <= DONE;
                            is_square <= 1'b1;
                        end else begin
                            i <= i + 16'd1;
                        end
                    end
                end

                DONE: begin
                    result <= is_square;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule