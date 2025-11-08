module TopModule(
    input clk,
    input [7:0] in,
    output reg [7:0] anyedge
);
    reg [7:0] prev_in;
    reg [7:0] edge_temp;
    always @(posedge clk) begin
        edge_temp <= (in != prev_in);
        prev_in <= in;
    end
    always @(posedge clk) begin
        anyedge <= edge_temp;
    end
endmodule