module dial_game(input clk, input rst_n, input start, input [3:0] A, input [3:0] B, input load, input [2:0] load_addr, input [3:0] load_data, output reg [7:0] sum_out, output reg done);
reg [3:0] dials [7:0];
reg [1:0] state;
reg [7:0] sum;
reg [2:0] current_index;
reg [3:0] current_A, current_B;
always_ff @(posedge clk)
if (!rst_n) begin
dials <= 8'b0;
state <= 2'b00;
sum <= 8'b0;
current_index <= 3'b0;
current_A <= 4'b0;
current_B <= 4'b0;
end else begin
case (state)
2'b00: begin
if (start) begin
current_A <= A;
current_B <= B;
sum <= 8'b0;
current_index <= A - 1;
state <= 2'b01;
end else if (load) begin
dials[load_addr] <= load_data;
end
end
2'b01: begin
sum <= sum + dials[current_index];
current_index <= current_index + 1;
if (current_index > (current_B - 1)) begin
state <= 2'b10;
end else begin
state <= 2'b01;
end
end
2'b10: begin
dials[current_index] <= (dials[current_index] + 1) == 10 ? 0 : (dials[current_index] + 1);
current_index <= current_index + 1;
if (current_index > (current_B - 1)) begin
state <= 2'b11;
end else begin
state <= 2'b10;
end
end
2'b11: begin
state <= 2'b00;
end
endcase
end
assign done = (state == 2'b11);
assign sum_out = done ? sum : 8'h00;
endmodule