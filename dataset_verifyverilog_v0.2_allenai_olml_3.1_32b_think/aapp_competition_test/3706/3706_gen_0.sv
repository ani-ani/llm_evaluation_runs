module karen_and_game(input clk, input rst_n, input start, output output_valid, output [7:0] output_char, output done);
reg [1:0] state;
always_ff @(posedge clk) begin
if (!rst_n) state <= 2'b00;
end
assign output_valid = 1'b0;
assign output_char = 8'h00;
assign done = 1'b0;
endmodule