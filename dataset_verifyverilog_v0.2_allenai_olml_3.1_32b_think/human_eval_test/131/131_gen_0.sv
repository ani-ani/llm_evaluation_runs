module digits_product (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] number,
    output reg [15:0] result,
    output reg done
);

reg [7:0] input_num;
reg [15:0] result_reg;
reg has_odd;
reg [2:0] state_reg;

localparam IDLE = 3'd0,
INIT = 3'd1,
PROCESS_0 = 3'd2,
PROCESS_1 = 3'd3,
PROCESS_2 = 3'd4,
DONE = 3'd5;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        input_num <= 8'b0;
        result_reg <= 16'b0;
        has_odd <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state_reg <= INIT;
                end else begin
                    state_reg <= IDLE;
                end
            end
            INIT: begin
                done <= 1'b0;
                input_num <= number;
                result_reg <= 16'd1;
                has_odd <= 1'b0;
                state_reg <= PROCESS_0;
            end
            PROCESS_0: begin
                done <= 1'b0;
                reg [7:0] current = input_num;
                reg [3:0] digit;
                digit = current % 10;
                if (digit[0]) begin
                    result_reg <= result_reg * digit;
                    has_odd <= 1'b1;
                end
                state_reg <= PROCESS_1;
            end
            PROCESS_1: begin
                done <= 1'b0;
                reg [7:0] current = input_num / 10;
                reg [3:0] digit = current % 10;
                if (digit[0]) begin
                    result_reg <= result_reg * digit;
                    has_odd <= 1'b1;
                end
                state_reg <= PROCESS_2;
            end
            PROCESS_2: begin
                done <= 1'b0;
                reg [7:0] current = input_num / 100;
                reg [3:0] digit = current % 10;
                if (digit[0]) begin
                    result_reg <= result_reg * digit;
                    has_odd <= 1'b1;
                end
                state_reg <= DONE;
            end
            DONE: begin
                done <= 1'b1;
                if (!has_odd)
                    result_reg <= 16'd0;
                state_reg <= DONE;
            end
            default: state_reg <= IDLE;
        endcase
    end
end

assign result = result_reg;

endmodule