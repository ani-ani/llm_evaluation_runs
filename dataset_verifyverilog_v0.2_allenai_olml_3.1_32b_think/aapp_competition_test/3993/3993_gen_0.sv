module special_discard_counter (
input clk,
input rst_n,
input start,
input [63:0] n_items,
input [3:0] num_special,
input [63:0] k_page,
input [15:0][63:0] special_indices,
output reg [7:0] result,
output reg done 
);

reg [2:0] state;
reg [7:0] result_reg;
reg done_reg;
reg [15:0] removed_flags;
reg [15:0] items_to_remove;
reg [63:0] k_page_reg;
reg [3:0] num_special_reg;
reg [15:0][63:0] special_indices_reg [15:0];
reg [63:0] n_items_reg;

always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
result_reg <= 8'd0;
done_reg <= 1'b0;
removed_flags <= 16'b0;
items_to_remove <= 16'b0;
k_page_reg <= 64'd0;
num_special_reg <= 4'd0;
for (int i=0; i<16; i++) begin
special_indices_reg[i] <= 64'd0;
end
n_items_reg <= 64'd0;
end else begin
k_page_reg <= k_page;
num_special_reg <= num_special;
n_items_reg <= n_items;
special_indices_reg[0] <= special_indices[0];
special_indices_reg[1] <= special_indices[1];
special_indices_reg[2] <= special_indices[2];
special_indices_reg[3] <= special_indices[3];
special_indices_reg[4] <= special_indices[4];
special_indices_reg[5] <= special_indices[5];
special_indices_reg[6] <= special_indices[6];
special_indices_reg[7] <= special_indices[7];
special_indices_reg[8] <= special_indices[8];
special_indices_reg[9] <= special_indices[9];
special_indices_reg[10] <= special_indices[10];
special_indices_reg[11] <= special_indices[11];
special_indices_reg[12] <= special_indices[12];
special_indices_reg[13] <= special_indices[13];
special_indices_reg[14] <= special_indices[14];
special_indices_reg[15] <= special_indices[15];
end
end

always @(*) begin
state <= state;
case (state):
3'd0: if (start) state <= 3'd1;
3'd1: state <= 3'd2;
3'd2: begin
result_reg <= result_reg + 1;
if (1) state <= 3'd3; else state <= 3'd1;
end
3'd3: state <= 3'd3;
default: state <= 3'd0;
endcase
end

assign result = result_reg;
assign done = done_reg;
endmodule