module swerc_fee_calculator (
input clk,
input rst_n,
input start,
input signed [15:0] swerc_cost,
input [3:0] swerc_hops,
input signed [15:0] comp_cost,
input [3:0] comp_hops,
output reg [15:0] result,
output reg [1:0] status,
output reg done
);
reg [1:0] state, next_state;
reg [15:0] captured_swerc_cost, captured_swerc_hops, captured_comp_cost, captured_comp_hops;
reg [15:0] numerator_reg, denominator_reg;
reg [15:0] result_reg;
reg [1:0] status_reg;
reg done_reg;
localparam IDLE = 2'b00;
localparam CHECK = 2'b01;
localparam DIVIDE = 2'b10;
localparam DONE = 2'b11;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
captured_swerc_cost <= 16'b0;
captured_swerc_hops <= 4'b0;
captured_comp_cost <= 16'b0;
captured_comp_hops <= 4'b0;
numerator_reg <= 16'b0;
denominator_reg <= 4'b0;
result_reg <= 16'b0;
status_reg <= 2'b00;
done_reg <= 1'b0;
end else begin
state <= next_state;
if (state == CHECK) begin
captured_swerc_cost <= swerc_cost;
captured_swerc_hops <= swerc_hops;
captured_comp_cost <= comp_cost;
captured_comp_hops <= comp_hops;
end
next_state = state;
case (state)
IDLE: begin
if (start) begin
next_state = CHECK;
end
end
CHECK: begin
if (captured_comp_hops <= captured_swerc_hops) begin
status_reg <= 2'b11;
done_reg <= 1'b1;
next_state = DONE;
end else begin
numerator_reg <= captured_comp_cost - captured_swerc_cost;
denominator_reg <= captured_comp_hops - captured_swerc_hops;
if (numerator_reg < 0) begin
status_reg <= 2'b10;
done_reg <= 1'b1;
next_state = DONE;
end else begin
next_state = DIVIDE;
end
end
end
DIVIDE: begin
if (numerator_reg == 0) begin
result_reg <= 16'b0;
status_reg <= 2'b01;
done_reg <= 1'b1;
next_state = DONE;
end else if (numerator_reg == 1) begin
result_reg <= 16'b0;
status_reg <= 2'b01;
done_reg <= 1'b1;
next_state = DONE;
end else begin
result_reg <= ( (unsigned(numerator_reg) - 1) ) / denominator_reg;
status_reg <= 2'b01;
done_reg <= 1'b1;
next_state = DONE;
end
end
DONE: begin
next_state = DONE;
end
endcase
result <= result_reg;
status <= status_reg;
done <= done_reg;
end
endmodule