module TopModule (
    input wire clk,
    input wire [7:0] in,
    output reg [7:0] anyedge
);
reg [7:0] prev = 8'b0;
always @(posedge clk) begin
    anyedge <= (in != prev);
    prev <= in;
end
endmodule