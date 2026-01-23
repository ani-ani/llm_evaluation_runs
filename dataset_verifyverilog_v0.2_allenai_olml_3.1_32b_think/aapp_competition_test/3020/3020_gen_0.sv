module carryless_sqrt (
    input clk,
    input rst_n,
    input start,
    input [39:0] n,
    input [3:0] num_digits,
    output reg [23:0] result,
    output reg [3:0] result_digits,
    output reg done,
    output reg found
);

    reg [2:0] state;
    reg [31:0] candidate;
    reg [23:0] computed_sq;
    reg done_reg;
    reg found_reg;
    reg [3:0] result_digits_reg;
    reg [23:0] result_reg;

    parameter IDLE = 3'b000;
    parameter SEARCH = 3'b001;
    parameter VERIFY = 3'b010;
    parameter DONE = 3'b100;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            candidate <= 32'b0;
            done_reg <= 1'b0;
            found_reg <= 1'b0;
            result_reg <= 24'b0;
            result_digits_reg <= 4'b0000;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SEARCH;
                        candidate <= 32'b1;
                    end
                end
                SEARCH: begin
                    candidate <= candidate + 32'd1;
                    if (candidate == 32'd1000) begin
                        state <= DONE;
                        found_reg <= 1'b0;
                        done_reg <= 1'b1;
                    end else begin
                        state <= VERIFY;
                    end
                end
                VERIFY: begin
                    state <= SEARCH;
                end
                DONE: begin
                    state <= DONE;
                end
            endcase
        end
    end

    assign result = result_reg;
    assign result_digits = result_digits_reg;
    assign done = done_reg;
    assign found = found_reg;

endmodule