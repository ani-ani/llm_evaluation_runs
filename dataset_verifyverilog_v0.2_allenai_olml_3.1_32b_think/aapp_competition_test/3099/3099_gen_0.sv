module spy_network(input clk, input rst_n, input start, input [2:0] num_spies, input [7:0] enemy_mask, input [7:0] adj_matrix [0:7], output reg [3:0] min_messages, output reg done);
reg [2:0] state;
reg [2:0] num_spies_reg;
reg [7:0] enemy_mask_reg;
reg [7:0][7:0] reach;
reg [9:0] reach_counter;
reg [2:0] k_counter, i_counter, j_counter;
reg [7:0] covered;
reg [3:0] min_count;
reg [2:0] next_state;
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
um_spies_reg <= 3'b0;
enemy_mask_reg <= 8'b0;
reach_counter <= 10'd0;
k_counter <= 3'd0;
i_counter <= 3'd0;
j_counter <= 3'd0;
covered <= 8'b0;
min_count <= 4'd0;
done <= 1'b0;
min_messages <= 4'd0;
state <= 3'd0;
end
else begin
case (state)
3'd0: begin
if (start) next_state = 3'd1;
else next_state = 3'd0;
done = 1'b0;
min_messages = 4'd0;
end
3'd1: begin
num_spies_reg <= num_spies;
enemy_mask_reg <= enemy_mask;
next_state = 3'd2;
end
3'd2: begin
if (reach_counter < 512) begin
if (j_counter < 8) j_counter <= j_counter + 1;
else begin
j_counter <= 0;
if (i_counter < 8) i_counter <= i_counter + 1;
else begin
i_counter <= 0;
if (k_counter < 8) k_counter <= k_counter + 1;
else begin
reach_counter <= reach_counter + 1;
if (reach_counter == 512) next_state = 3'd3;
end
end
end
end
end
3'd3: begin
done = 1'b1;
min_messages = min_count;
next_state = 3'd4;
end
3'd4: next_state = 3'd4;
endcase
state <= next_state;
end
end
endmodule