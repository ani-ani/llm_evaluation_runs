module arcaea_diversity (input clk,input rst_n,input start,input [2:0] n,input [2:0] k,input [7:0] frag [8],input [7:0] step [8],input [7:0] frag_awaken [8],input [7:0] step_awaken [8],output reg [3:0] result,output reg done);
reg [7:0] current_mask;
reg [3:0] max_div;
reg [2:0] state;

always_ff @(posedge clk) begin
if (!rst_n) begin
current_mask <= 0;
max_div <= 0;
state <= 0;
done <= 0;
end
else begin
if (state == 1) current_mask <= current_mask + 1;
state <= state;
done <= done;
end
end

always_comb begin
reg state_next, done_next, result_next, max_div_next;
state_next = state;
done_next = done;
result_next = result;
max_div_next = max_div;

if (state == 0) begin
if (!rst_n) state_next = 0;
else if (start) begin
state_next = 1;
current_mask_next = 0;
max_div_next = 0;
end
end
else if (state == 1) begin
if (current_mask >= 256) begin
state_next = 2;
done_next = 1;
result_next = max_div;
end
end
end

assign result = result_next;
assign done = done_next;
endmodule