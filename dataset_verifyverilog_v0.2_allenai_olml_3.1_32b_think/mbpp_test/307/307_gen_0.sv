module colon_tuplex (input clk, input rst_n, input start, input [2:0] m, input [7:0] n, input [7:0] tuplex_0, input [7:0] tuplex_1, input [7:0] tuplex_2, input [7:0] tuplex_3, output reg [7:0] result_0, output reg [7:0] result_1, output reg [7:0] result_2, output reg [7:0] result_3, output reg done);
localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE_STATE = 2'd2;
wire [7:0] modified_result_0;
assign modified_result_0 = (m == 3'd0) ? n : tuplex_0;
wire [7:0] modified_result_1;
assign modified_result_1 = (m == 3'd1) ? n : tuplex_1;
wire [7:0] modified_result_2;
assign modified_result_2 = (m == 3'd2) ? n : tuplex_2;
wire [7:0] modified_result_3;
assign modified_result_3 = (m == 3'd3) ? n : tuplex_3;
assign result_0 = (state == DONE_STATE) ? modified_result_0 : tuplex_0;
assign result_1 = (state == DONE_STATE) ? modified_result_1 : tuplex_1;
assign result_2 = (state == DONE_STATE) ? modified_result_2 : tuplex_2;
assign result_3 = (state == DONE_STATE) ? modified_result_3 : tuplex_3;
assign done = (state == DONE_STATE);
reg [1:0] state;
reg first_time;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        first_time <= 1'b0;
    end else begin
        if (start && state == IDLE) begin
            state <= PROCESSING;
            first_time <= 1'b1;
        end
        if (state == PROCESSING) begin
            if (first_time) begin
                first_time <= 1'b0;
            end else begin
                state <= DONE_STATE;
            end
        end
    end
end
endmodule