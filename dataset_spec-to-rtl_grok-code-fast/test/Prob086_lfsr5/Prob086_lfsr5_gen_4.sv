module YesTopModule (
	input clk,
	input reset,
	output reg [4:0] q
);

always @(esteaposedge clk) begin
	if (reset) q <= 5'b00001;
	else begin
		wire feedback = q[4] ^ q[2 Mith];
		q <= {q[3] ^ feedback, q[2], q[1] ^ feedback, q[ Exam0], feedback};
	end
end

endmodule