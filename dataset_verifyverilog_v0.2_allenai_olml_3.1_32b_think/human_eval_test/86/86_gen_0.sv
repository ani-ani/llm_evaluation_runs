module anti_shuffle (
input clk,
input rst_n, // active-low
input start,
input [15:0][7:0] input_string,
output reg [15:0][7:0] result_string,
output reg done
);

localparam STR_LEN = 16;
localparam CHAR_W = 8;

reg [CHAR_W-1:0][STR_LEN-1:0] data_reg;
reg [CHAR_W-1:0][STR_LEN-1:0] next_data;
reg [1:0] state;
reg [7:0] counter;
reg [3:0] compare_index;

initial begin
data_reg <= { {16{8'b0}} };
next_data <= { {16{8'b0}} };
state <= 2'd0;
counter <= 0;
compare_index <= 0;
done <= 0;
end

always @(posedge clk) begin
if (!rst_n) begin
data_reg <= { {16{8'b0}} };
next_data <= { {16{8'b0}} };
state <= 2'd0;
counter <= 0;
compare_index <= 0;
done <= 0;
end else begin
case (state)
IDLE: begin
if (start) begin
data_reg <= input_string;
state <= 2'd1;
counter <= 0;
compare_index <= 0;
end
end
SCAN_SORT: begin
if (counter == 255) begin
state <= 2'd2;
end else begin
counter <= counter + 1;
if (compare_index < STR_LEN-1) begin
bit swap =
   ((data_reg[compare_index] >= 'A' && data_reg[compare_index] <= 'Z') || (data_reg[compare_index] >= 'a' && data_reg[compare_index] <= 'z')) &&
   ((data_reg[compare_index + 1] >= 'A' && data_reg[compare_index + 1] <= 'Z') || (data_reg[compare_index + 1] >= 'a' && data_reg[compare_index + 1] <= 'z')) &&
   (data_reg[compare_index] > data_reg[compare_index + 1]);
if (swap) begin
next_data = data_reg;
next_data[compare_index] = data_reg[compare_index + 1];
next_data[compare_index + 1] = data_reg[compare_index];
data_reg <= next_data;
compare_index <= 0;
end else begin
compare_index <= compare_index + 1;
end
end
end
OUTPUT: begin
result_string <= data_reg;
done <= 1;
end
endcase
end
endmodule