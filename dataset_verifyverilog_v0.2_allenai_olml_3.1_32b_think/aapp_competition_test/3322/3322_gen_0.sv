module antique_shopping(input clk, input rst_n, input start, input [2:0] k, input [3:0] antique0_orig_shop, input [23:0] antique0_orig_price, input [3:0] antique0_knock_shop, input [23:0] antique0_knock_price, input [3:0] antique1_orig_shop, input [23:0] antique1_orig_price, input [3:0] antique1_knock_shop, input [23:0] antique1_knock_price, input [3:0] antique2_orig_shop, input [23:0] antique2_orig_price, input [3:0] antique2_knock_shop, input [23:0] antique2_knock_price, input [3:0] antique3_orig_shop, input [23:0] antique3_orig_price, input [3:0] antique3_knock_shop, input [23:0] antique3_knock_price, output reg [23:0] min_cost, output reg valid, output reg done);
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
min_cost_reg <= 32'd(1<<24);
computation_done <= 0;
cycle_counter <= 0;
valid <= 0;
done <= 0;
mask_counter <= 0;
current_mask <= 0;
bit_count <= 0;
total_cost <= 0;
end else begin
case (state)
3'd0: begin
if (start) begin
state <= 3'd1;
mask_counter <= 1;
end
end
3'd1: begin
if (mask_counter < 256) begin
current_mask <= mask_counter;
bit_count <= (current_mask[0] ? 1 :0) + (current_mask[1] ? 1 :0) + (current_mask[2] ? 1 :0) + (current_mask[3] ? 1 :0) + (current_mask[4] ? 1 :0) + (current_mask[5] ? 1 :0) + (current_mask[6] ? 1 :0) + (current_mask[7] ? 1 :0);
if (bit_count > k) begin
mask_counter <= mask_counter + 1;
end else begin
state <= 3'd2;
end
end else begin
computation_done <= 1;
state <= 3'd5;
end
end
3'd2: begin
reg [23:0] min0, min1, min2, min3;
reg valid_comb;
valid_comb = 1'b1;
// Antique 0
min0 = 32'd(1<<24);
if (current_mask[antique0_orig_shop]) min0 = antique0_orig_price;
if (current_mask[antique0_knock_shop]) min0 = (min0 < antique0_knock_price) ? min0 : antique0_knock_price;
if (min0 == 32'd(1<<24)) valid_comb = 0;
// Antique 1
min1 = 32'd(1<<24);
if (current_mask[antique1_orig_shop]) min1 = antique1_orig_price;
if (current_mask[antique1_knock_shop]) min1 = (min1 < antique1_knock_price) ? min1 : antique1_knock_price;
if (min1 == 32'd(1<<24)) valid_comb = 0;
// Antique 2
min2 = 32'd(1<<24);
if (current_mask[antique2_orig_shop]) min2 = antique2_orig_price;
if (current_mask[antique2_knock_shop]) min2 = (min2 < antique2_knock_price) ? min2 : antique2_knock_price;
if (min2 == 32'd(1<<24)) valid_comb = 0;
// Antique 3
min3 = 32'd(1<<24);
if (current_mask[antique3_orig_shop]) min3 = antique3_orig_price;
if (current_mask[antique3_knock_shop]) min3 = (min3 < antique3_knock_price) ? min3 : antique3_knock_price;
if (min3 == 32'd(1<<24)) valid_comb = 0;
if (valid_comb) begin
state <= 3'd3;
total_cost <= min0 + min1 + min2 + min3;
end else begin
state <= 3'd1;
mask_counter <= mask_counter + 1;
end
end
3'd3: begin
state <= 3'd4;
end
3'd4: begin
if (total_cost < min_cost_reg) begin
min_cost_reg <= total_cost;
end
state <= 3'd1;
mask_counter <= mask_counter + 1;
end
3'd5: begin
if (computation_done) begin
if (cycle_counter == 0) begin
valid <= 1;
done <= 1;
end else begin
cycle_counter <= cycle_counter - 1;
end
end
endcase
end
end
assign min_cost = min_cost_reg;
assign valid = valid;
assign done = done;
endmodule