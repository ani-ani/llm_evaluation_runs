module prime_factorizer(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] factors [0:7],
    output reg [3:0] factor_count,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [15:0] remainder;
    reg [15:0] divisor;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i = 0; i < 8; i = i + 1) begin
                factors[i] <= 16'd0;
            end
            factor_count <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            remainder <= 16'd0;
            divisor <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    // Initialize for new computation
                    for (i = 0; i < 8; i = i + 1) begin
                        factors[i] <= 16'd0;
                    end
                    factor_count <= 4'd0;
                    remainder <= n;
                    divisor <= 16'd2;
                    cycle_count <= 8'd0;
                    valid <= 1'b1;  // Assume valid until proven otherwise
                    next_state = CALCULATING;
                end
            end

            CALCULATING: begin
                if (remainder == 16'd1) begin
                    next_state = DONE_STATE;
                end else if (divisor > remainder || cycle_count >= MAX_CYCLES) begin
                    valid <= 1'b0;  // Factorization failed
                    next_state = DONE_STATE;
                end else begin
                    if (remainder % divisor == 16'd0) begin
                        // Found a factor
                        if (factor_count < 8) begin
                            factors[factor_count] <= divisor;
                            factor_count <= factor_count + 4'd1;
                            remainder <= remainder / divisor;
                        end else begin
                            valid <= 1'b0;  // Too many factors
                            next_state = DONE_STATE;
                        end
                    end else begin
                        divisor <= divisor + 16'd1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule