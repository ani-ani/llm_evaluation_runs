module wire_bending(input clk, input rst_n, input start, input [3:0] bend_point, input bend_dir, input bend_valid, output reg ghost, output reg done);
reg [2:0] state;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'd0; ghost <= 1'b0; done <= 1'b0;
end else begin
state <= 3'd0;
end
end
endmodule