module tweeper_decoder (
input clk,
input rst_n,
input start,
input [7:0] i_char,
input [7:0] o_char,
input [3:0] i_idx,
input [3:0] o_idx,
input i_valid,
input i_last,
input o_last,
output reg [7:0] enc_plus,
output reg [7:0] enc_minus,
output reg [1:0] result_code,
output reg done
);

localparam IDLE = 2'd0;
localparam COLLECT = 2'd1;
localparam PROCESS = 2'd2;
localparam DELAY = 2'd3;
localparam DONE_STATE = 2'd4;

reg [1:0] state, next_state;
reg [7:0] i_char_reg [0:15], o_char_reg [0:15];
reg [15:0] i_valid_reg;
reg [1:0] result_code_int;
reg [7:0] enc_plus_int, enc_minus_int;
reg done_int;
reg [15:0] delay_counter;
reg started;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
i_char_reg <= 16{8{1'b0}};
o_char_reg <= 16{8{1'b0}};
i_valid_reg <= 16'd0;
delay_counter <= 16'd0;
started <= 1'b0;
result_code_int <= 2'd0;
enc_plus_int <= 8'b0;
enc_minus_int <= 8'b0;
done_int <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
next_state <= COLLECT;
started <= 1'b1;
end else begin
next_state <= IDLE;
end
end
COLLECT: begin
if (i_valid) begin
i_char_reg[i_idx] <= i_char;
o_char_reg[i_idx] <= o_char;
i_valid_reg <= i_valid_reg | (1 << i_idx);
end
if (i_valid && i_last) begin
next_state <= PROCESS;
end else begin
next_state <= COLLECT;
end
end
PROCESS: begin
enc_plus_int <= 8'b0;
enc_minus_int <= 8'b0;
result_code_int <= 2'd1;
next_state <= DELAY;
end
DELAY: begin
if (started) begin
delay_counter <= delay_counter + 1;
if (delay_counter == 256'd256) begin
next_state <= DONE_STATE;
done_int <= 1'b1;
end else begin
next_state <= DELAY;
end
end else begin
next_state <= IDLE;
end
end
DONE_STATE: begin
next_state <= DONE_STATE;
done_int <= 1'b1;
end
endcase
state <= next_state;
end
end

assign enc_plus = enc_plus_int;
assign enc_minus = enc_minus_int;
assign result_code = result_code_int;
assign done = done_int;

endmodule