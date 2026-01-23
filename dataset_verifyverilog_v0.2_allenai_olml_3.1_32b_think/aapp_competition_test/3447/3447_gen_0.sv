module sms_typing_optimizer(input clk, input rst_n, input start, input [7:0] dict_size, input [7:0] dict_words [0:7][0:7], input [7:0] dict_lens [0:7], input [7:0] target [0:15], input [7:0] target_len, output reg [31:0] min_presses, output reg done, output reg [255:0] debug_path);
parameter IDLE = 2'b00;
parameter CAPTURE = 2'b01;
parameter DP_COMPUTE = 2'b10;
parameter DONE = 2'b11;

reg [1:0] state, next_state;
reg [31:0] dp [0:16];
reg [7:0] dict_size_reg;
reg [7:0] dict_words_reg [0:7][0:7];
reg [7:0] dict_lens_reg [0:7];
reg [7:0] target_reg [0:15];
reg [7:0] target_len_reg;
reg [1:0] i_state;
reg [2:0] w_state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        dict_size_reg <= 8'd0;
        target_len_reg <= 8'd0;
        dp[0] <= 32'd0;
        dp[1] <= 32'd0xFFFFFFFF;
        dp[2] <= 32'd0xFFFFFFFF;
        dp[3] <= 32'd0xFFFFFFFF;
        dp[4] <= 32'd0xFFFFFFFF;
        dp[5] <= 32'd0xFFFFFFFF;
        dp[6] <= 32'd0xFFFFFFFF;
        dp[7] <= 32'd0xFFFFFFFF;
        dp[8] <= 32'd0xFFFFFFFF;
        dp[9] <= 32'd0xFFFFFFFF;
        dp[10] <= 32'd0xFFFFFFFF;
        dp[11] <= 32'd0xFFFFFFFF;
        dp[12] <= 32'd0xFFFFFFFF;
        dp[13] <= 32'd0xFFFFFFFF;
        dp[14] <= 32'd0xFFFFFFFF;
        dp[15] <= 32'd0xFFFFFFFF;
        dp[16] <= 32'd0xFFFFFFFF;
        i_state <= 2'b00;
        w_state <= 3'b000;
        done <= 1'b0;
        min_presses <= 32'd0;
        debug_path <= 256'd0;
    end else begin
        state <= next_state;
        if (state == CAPTURE) begin
            dict_size_reg <= dict_size;
            dict_words_reg <= dict_words;
            dict_lens_reg <= dict_lens;
            target_reg <= target;
            target_len_reg <= target_len;
            next_state <= DP_COMPUTE;
        end
    end
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            next_state = CAPTURE;
        end
    end else if (state == CAPTURE) begin
        next_state = DP_COMPUTE;
    end else if (state == DP_COMPUTE) begin
        next_state = DONE;
    end else if (state == DONE) begin
        next_state = DONE;
    end
end

assign done = (state == DONE);
assign min_presses = (state == DONE) ? dp[target_len_reg] : 32'd0;
assign debug_path = 256'd0;

endmodule