module power_calculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] base,
    input [4:0] exponent,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [4:0] counter;
    reg [31:0] accumulator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 5'd0;
            accumulator <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        accumulator <= 32'd1;  // Initialize for exponentiation
                        counter <= exponent;
                    end
                end

                COMPUTE: begin
                    if (counter > 5'd0) begin
                        accumulator <= accumulator * base;
                        counter <= counter - 5'd1;
                    end else begin
                        result <= accumulator;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule