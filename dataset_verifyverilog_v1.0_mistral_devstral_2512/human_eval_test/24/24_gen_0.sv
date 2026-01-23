module largest_divisor(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CHECKING   = 2'd1;
    localparam [1:0] CALCULATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [15:0] divisor;
    reg [15:0] remainder;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Remainder calculation (combinational)
    always @(*) begin
        remainder = n % divisor;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            divisor <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECKING;
                        divisor <= n >> 1;  // Start from n/2
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECKING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (remainder == 16'd0) begin
                        next_state <= CALCULATING;
                    end else if (divisor == 16'd1) begin
                        next_state <= CALCULATING;
                    end else begin
                        divisor <= divisor - 16'd1;
                        next_state <= CHECKING;
                    end
                end

                CALCULATING: begin
                    if (divisor == 16'd1) begin
                        result <= 16'd1;  // Special case for n=1
                    end else if (remainder == 16'd0) begin
                        result <= divisor;
                    end else begin
                        result <= 16'd1;  // No divisor found (shouldn't happen for n>1)
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule