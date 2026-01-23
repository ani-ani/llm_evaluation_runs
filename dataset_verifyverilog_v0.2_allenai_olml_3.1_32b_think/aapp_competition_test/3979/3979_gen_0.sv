module lexicographical_solver(input clk, input rst_n, input start, input [3:0] word_len_1, input [15:0] word_1 [16], input [3:0] word_len_2, input [15:0] word_2 [16], output reg [15:0] capitalization_mask, output reg valid, output reg impossible);
parameter IDLE = 2'd0;
parameter COMPARE = 2'd1;
parameter PROPAGATE = 2'd2;
parameter DONE = 2'd3;

reg [1:0] state;
reg [3:0] compare_counter;
reg [3:0] mismatch_pos;
reg [1:0] mismatch_type;
reg [3:0] hard_pos;
reg [1:0] hard_value;
reg [3:0] done_timer;
reg [15:0] cap_mask;

reg valid_out, impossible_out;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        compare_counter <= 4'd0;
        mismatch_pos <= 4'd0;
        mismatch_type <= 2'd2;
        hard_pos <= 4'd0;
        hard_value <= 2'd0;
        done_timer <= 4'd0;
        cap_mask <= 16'd0;
        valid_out <= 1'b0;
        impossible_out <= 1'b0;
    end
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            state <= COMPARE;
            compare_counter <= 4'd0;
            mismatch_pos <= 4'd0;
            mismatch_type <= 2'd2;
            hard_pos <= 4'd0;
            hard_value <= 2'd0;
            done_timer <= 4'd0;
            cap_mask <= 16'd0;
            valid_out <= 1'b0;
            impossible_out <= 1'b0;
        end
    end else if (state == COMPARE) begin
        if (word_len_1 <= word_len_2) begin
            state <= DONE;
            impossible_out = 1'b0;
        end else begin
            impossible_out = 1'b1;
            state <= DONE;
        end
    end else if (state == PROPAGATE) begin
        state <= DONE;
    end else if (state == DONE) begin
        if (done_timer == 4'd0) begin
            valid_out = !impossible_out;
        end
        done_timer <= done_timer - 1;
        if (done_timer < 4'd0) begin
            done_timer <= 4'd0;
        end
    end
end

assign capitalization_mask = cap_mask;
assign valid = valid_out;
assign impossible = impossible_out;

endmodule