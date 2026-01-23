module bank_account_checker (input clk, input rst_n, input start, input valid_in, input signed [15:0] operation, output reg balance_below_zero, output reg done);
reg [2:0] state;
reg signed [15:0] balance;
reg balance_below_zero;
reg done_reg;

always @(posedge clk) begin
if (!rst_n) begin
state <= 3'b000;
balance <= 0;
balance_below_zero <= 0;
done_reg <= 0;
end else begin
case(state)
3'b000: begin
if (start == 1) state <= 3'b001;
end
3'b001: begin
if (valid_in == 1) begin
balance <= balance + operation;
if (balance < 0) balance_below_zero <= 1;
end else begin
state <= 3'b010;
done_reg <= 1;
end
end
3'b010: begin
if (start == 1) begin
state <= 3'b000;
balance <= 0;
balance_below_zero <= 0;
done_reg <= 0;
end
end
endcase
end
end

assign done = done_reg;
endmodule