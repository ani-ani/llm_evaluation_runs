module TopModule (
    input clk,
    input [7:0] in,
    output [7:0] pedge
);

reg [7:0] prev = 8'd0;
reg [7:0] transition_reg = 8'd0;
reg [7:0] pedge_reg = 8'd0;

assign pedge = pedge_reg;

always @(posedge clk) begin
    transition_reg <= ~prev & in;
    prev <= in;
    pedge_reg <= transition_reg;
end

endmodule