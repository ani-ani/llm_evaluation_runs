module nephren_solver (
input clk,
input rst_n,
input start,
input [19:0] n_in,
input [59:0] k_in,
output reg [7:0] char_out,
output reg done
);

localparam integer LEN_BASE = 75;
localparam integer LEN_PREFIX = 34;
localparam integer LEN_MID = 32;
localparam integer LEN_SUFFIX = 2;

reg [7:0] prefix_rom [33:0];
initial begin prefix_rom = 0; end

reg [7:0] mid_rom [31:0];
initial begin mid_rom = 0; end

reg [7:0] suffix_rom [1:0];
initial begin suffix_rom = 0; end

reg [7:0] f0_rom [74:0];
initial begin f0_rom = 0; end

reg [2:0] state, next_state;
reg [59:0] current_k;
reg [31:0] current_n;
reg done_reg;
reg [7:0] char_out_reg;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'b000;
current_n <= 0;
current_k <= 0;
done_reg <= 0;
char_out_reg <= 0;
end else begin
state <= next_state;
if (state == 3'b000) begin // IDLE
if (start) begin
next_state <= 3'b001;
current_n <= n_in;
current_k <= k_in;
end
end else if (state == 3'b001) begin // PROCESSING
next_state <= 3'b010; // Default to DONE
if (current_n == 0) begin
if (current_k <= LEN_BASE) begin
char_out_reg <= f0_rom[current_k];
done_reg <= 1;
end else begin
char_out_reg <= 8'd46; // '.'
done_reg <= 1;
end
end else begin
if (current_k <= LEN_PREFIX) begin
char_out_reg <= prefix_rom[current_k];
done_reg <= 1;
end else begin
current_k = current_k - LEN_PREFIX;
if (1) begin // placeholder for f_len check
current_n = current_n - 1;
next_state <= 3'b001;
end
end
end
end
end
end
assign char_out = char_out_reg;
assign done = done_reg;

endmodule