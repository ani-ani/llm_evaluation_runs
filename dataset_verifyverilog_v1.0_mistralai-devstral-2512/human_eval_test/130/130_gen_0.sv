module TribonacciGenerator(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg signed [31:0] result,
    output reg [4:0] index,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] current_index;
    reg [4:0] max_index;

    // Compute the Tribonacci value
    wire signed [31:0] computed_value;
    wire [4:0] i = current_index;

    assign computed_value = (i[0] == 1'b0) ? 
        ((i >> 1) + 1'b1) << 16 :  // Even: i/2 + 1 in Q16.16
        ((((i + 3'd3) >> 1) * ((i + 3'd3) >> 1)) - 1'b1) << 16;  // Odd: ((i+3)/2)^2 - 1 in Q16.16

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_index <= 5'd0;
            index <= 5'd0;
            result <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
            max_index <= 5'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        max_index <= n;
                        current_index <= 5'd0;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    result <= computed_value;
                    index <= current_index;
                    valid <= 1'b1;
                    if (current_index == max_index) begin
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        done <= 1'b0;
                        current_index <= current_index + 5'd1;
                        next_state <= COMPUTE;
                    end
                end

                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule