module marble_insertion_dp (
input clk,
input rst_n,
input start,
input [7:0] N,
input [2:0] K,
input [7:0] marble_colors [0:15],
output reg [7:0] min_insertions,
output reg done
);

reg [2:0] state;
localparam IDLE=3'd0, INIT=3'd1, COMPUTE=3'd2, DONE=3'd3;
state <= IDLE;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) state <= IDLE;
else if (state == IDLE && start) state <= INIT;
else if (state == INIT) state <= COMPUTE;
else if (state == COMPUTE) state <= DONE;
end

always @(*) begin
done = (state == DONE);
min_insertions = 8'b0;
end

endmodule