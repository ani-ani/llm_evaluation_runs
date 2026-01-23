module limak_tower (input clk, input rst_n, input start, input [49:0] m_in, output reg [5:0] blocks_out, output reg [49:0] volume_out, output reg done);

reg [49:0] m;
reg [5:0] blocks;
reg [49:0] volume;

always @(posedge clk) begin
 if (!rst_n) begin
 m <= 0;
 blocks <= 0;
 volume <= 0;
 done <= 0;
 end else begin
 if (start) begin
 m <= m_in;
 blocks <= 1;
 volume <= m_in;
 done <= 1;
 end
 end
end

assign blocks_out = blocks;
assign volume_out = volume;
endmodule