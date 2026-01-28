module PerfectSquareChecker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] num_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] COMPUTING  = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [15:0] i;
    reg [15:0] num_reg;
    reg result_reg;
    reg done_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Combinational logic
    wire [31:0] i_sq;
    wire [15:0] quotient;
    wire [15:0] remainder;
    wire is_divisor;
    wire is_square_cond;

    // 32-bit multiplication for i*i
    assign i_sq = i * i;

    // Division and modulo
    assign quotient = num_reg / i;
    assign remainder = num_reg % i;

    // Conditions
    assign is_divisor = (remainder == 16'd0);
    assign is_square_cond = is_divisor && (quotient == i);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTING;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTING: begin
                if ((i_sq > num_reg) || (cycle_count >= MAX_CYCLES) || is_square_cond) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTING;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 16'd0;
            num_reg <= 16'd0;
            result_reg <= 1'b0;
            done_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            done <= done_reg;
            result <= result_reg;
            done_reg <= 1'b0;

            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load inputs
                        num_reg <= num_in;
                        result_reg <= 1'b0;
                        // Special case: num_in = 0 is a perfect square (0*0)
                        if (num_in == 16'd0) begin
                            result_reg <= 1'b1;
                            i <= 16'd0;
                        end else begin
                            i <= 16'd1;
                        end
                    end
                end

                COMPUTING: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (is_square_cond) begin
                        result_reg <= 1'b1;
                        done_reg <= 1'b1;
                    end else if (i_sq > num_reg) begin
                        // Not a perfect square
                        result_reg <= 1'b0;
                        done_reg <= 1'b1;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Timeout - not a square
                        result_reg <= 1'b0;
                        done_reg <= 1'b1;
                    end else begin
                        // Continue iteration
                        i <= i + 16'd1;
                    end
                end

                DONE_STATE: begin
                    // done_reg already set to 1 in COMPUTING
                    // State will transition to IDLE next cycle
                end

                default: begin
                    // Should not reach here
                    i <= 16'd0;
                    num_reg <= 16'd0;
                    result_reg <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule