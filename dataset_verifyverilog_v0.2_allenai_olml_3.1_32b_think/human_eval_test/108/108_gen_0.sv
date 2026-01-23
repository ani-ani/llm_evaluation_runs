module count_nums (
    input clk,
    input rst_n,
    input start,
    input [4:0] array_size,
    input signed [7:0] arr [0:15],
    output reg [4:0] result,
    output reg done 
);

reg [4:0] index;
reg [4:0] result_reg;
reg [4:0] sum_abs_reg;
reg [3:0] msb_reg;
reg sign_reg;
reg [7:0] current_num_reg;
reg [2:0] state;

localparam IDLE = 3'b000;
localparam LOAD_NUM = 3'b001;
localparam SUM_DIGITS = 3'b010;
localparam CHECK_COUNT = 3'b011;
localparam DONE = 3'b100;

always @(posedge clk) begin
    if (!rst_n) begin
        index <= 0;
        result_reg <= 0;
        sum_abs_reg <= 0;
        msb_reg <= 0;
        sign_reg <= 0;
        current_num_reg <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD_NUM;
            end
            LOAD_NUM: begin
                if (index < array_size) begin
                    current_num_reg <= arr[index];
                    state <= SUM_DIGITS;
                end else begin
                    state <= DONE;
                end
            end
            SUM_DIGITS: begin
                sign_reg <= current_num_reg < 0 ? 1'b1 : 1'b0;
                sum_abs_reg <= 0;
                msb_reg <= 0;
                if (((current_num_reg >= 100) || (current_num_reg <= -100))) begin
                    msb_reg <= 1;
                    sum_abs_reg <= 1;
                    if (((current_num_reg >= 110) || (current_num_reg <= -110))) begin
                        if (current_num_reg >= 0) begin
                            sum_abs_reg <= 1 + ((current_num_reg - 100) / 10) + ((current_num_reg - 100) % 10);
                        end else begin
                            sum_abs_reg <= 1 + ((-current_num_reg - 100) / 10) + ((-current_num_reg - 100) % 10);
                        end
                    end else if (current_num_reg != 0) begin
                        sum_abs_reg <= 1 + (current_num_reg >= 0 ? (current_num_reg - 100) : (-current_num_reg - 100));
                    end
                end else if (((current_num_reg >= 10) || (current_num_reg <= -10))) begin
                    if (current_num_reg >= 0) begin
                        msb_reg <= current_num_reg / 10;
                        sum_abs_reg <= msb_reg + (current_num_reg % 10);
                    end else begin
                        msb_reg <= (-current_num_reg) / 10;
                        sum_abs_reg <= msb_reg + ((-current_num_reg) % 10);
                    end
                end else begin
                    if (current_num_reg != 0) begin
                        msb_reg <= current_num_reg < 0 ? -current_num_reg : current_num_reg;
                        sum_abs_reg <= msb_reg;
                    end
                end
                state <= CHECK_COUNT;
            end
            CHECK_COUNT: begin
                if (sign_reg) begin
                    if (sum_abs_reg > (msb_reg << 1)) begin
                        result_reg <= result_reg + 1;
                    end
                end else begin
                    if (sum_abs_reg > 0) begin
                        result_reg <= result_reg + 1;
                    end
                end
                if (index < array_size) begin
                    index <= index + 1;
                    state <= LOAD_NUM;
                end else begin
                    state <= DONE;
                end
            end
            DONE: state <= DONE;
        endcase
    end
endmodule