module tetrahedron_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] side,  // Q16.16
    output reg [31:0] result, // Q16.16
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SQUARE = 3'd1;
    localparam [2:0] MULTIPLY = 3'd2;
    localparam [2:0] SQRT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Intermediate registers
    reg [31:0] square_result;  // Q16.16
    reg [31:0] multiply_result; // Q16.16
    reg [31:0] sqrt_result;    // Q16.16

    // Constants
    localparam [31:0] SQRT3 = 32'h1B504; // 1.7320508075688772 in Q16.16

    // Square calculation
    wire signed [63:0] square_temp;
    assign square_temp = $signed(side) * $signed(side);

    // Multiply by sqrt(3)
    wire signed [63:0] multiply_temp;
    assign multiply_temp = $signed(square_result) * $signed(SQRT3);

    // Integer square root (Newton-Raphson method)
    reg [47:0] sqrt_input;  // 48-bit input for sqrt
    reg [23:0] sqrt_iter;   // 24-bit result (Q8.24)
    reg [23:0] sqrt_next;
    reg [7:0] sqrt_cycle;
    localparam [7:0] SQRT_ITERATIONS = 8'd16;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            square_result <= 32'd0;
            multiply_result <= 32'd0;
            sqrt_result <= 32'd0;
            sqrt_cycle <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SQUARE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SQUARE: begin
                    square_result <= square_temp[47:16]; // Middle 32 bits (Q16.16)
                    next_state <= MULTIPLY;
                end

                MULTIPLY: begin
                    multiply_result <= multiply_temp[47:16]; // Middle 32 bits (Q16.16)
                    next_state <= SQRT;
                end

                SQRT: begin
                    // Initialize sqrt calculation
                    if (sqrt_cycle == 0) begin
                        sqrt_input <= {16'd0, multiply_result[31:0]}; // Scale to Q8.24
                        sqrt_iter <= 24'd0;
                        sqrt_cycle <= sqrt_cycle + 8'd1;
                    end else if (sqrt_cycle < SQRT_ITERATIONS) begin
                        // Newton-Raphson iteration: x = (x + input/x) / 2
                        if (sqrt_iter == 0) begin
                            sqrt_next <= sqrt_input[47:24]; // Initial guess
                        end else begin
                            wire signed [47:0] div_temp = sqrt_input / sqrt_iter;
                            sqrt_next <= (sqrt_iter + div_temp[47:24]) >> 1;
                        end
                        sqrt_iter <= sqrt_next;
                        sqrt_cycle <= sqrt_cycle + 8'd1;
                    end else begin
                        // Convert Q8.24 to Q16.16
                        sqrt_result <= {8'd0, sqrt_iter[23:8]}; // Shift left by 8 bits
                        next_state <= FINISH;
                        sqrt_cycle <= 8'd0;
                    end
                end

                FINISH: begin
                    result <= sqrt_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
                cycle_count <= 8'd0;
            end
        end
    end

    // Handle edge cases
    always @(*) begin
        if (side == 32'd0) begin
            result = 32'd0;
        end
    end

endmodule