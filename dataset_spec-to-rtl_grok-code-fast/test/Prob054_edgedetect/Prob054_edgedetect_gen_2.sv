module TopModule(
    input clk,
    input [7:0] in,
    output [7:0] pedge
);
    reg [7:0] prev_in;
    reg [7:0] pedge_reg;
    reg [7:0] edge_now;
    assign pedge = pedge_reg;
    always @(posedge clk) begin
        edge_now = in & ~prev_in;
        prev_in <= in;
        pedge_reg <= edge_now;
    end
endmodule