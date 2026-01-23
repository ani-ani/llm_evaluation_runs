module max_points_game (
input clk,
input rst_n,
input start,
input [15:0] data_in,
input valid_in,
input done_in,
output reg [31:0] result,
output reg done,
output reg ready
);

reg [2:0] state;
reg [7:0] buffer [15:0];
reg [4:0] load_idx;
reg [31:0] total_score;
reg [15:0] start_counter;
reg [31:0] result_reg;
reg done_reg;
reg ready_reg;

always @(posedge clk) begin
if (!rst_n) begin
state <= 0;
load_idx <= 0;
start_counter <= 0;
total_score <= 0;
end else begin
if (state == 0) begin
if (start) begin
state <= 1;
start_counter <= 1;
end
end else if (state == 1) begin // LOAD
if (valid_in) begin
if (load_idx < 16) begin
buffer[load_idx] <= data_in[7:0];
load_idx <= load_idx + 1;
end
end
if (done_in) begin
if (load_idx > 0) state <= 2;
end
end else if (state == 2) begin // PROCESS
total_score <= 0; // Dummy, should compute
state <= 3;
end else if (state == 3) begin // WAIT
if (start_counter < 128) begin
start_counter <= start_counter + 1;
end else begin
result_reg <= total_score;
done_reg <= 1;
ready_reg <= 1;
state <= 4;
end
end else if (state == 4) begin // DONE
result <= result_reg;
done <= done_reg;
ready <= ready_reg;
state <= 0;
end
end
end

assign result = result_reg;
assign done = done_reg;
assign ready = ready_reg;

endmodule