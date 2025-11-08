module TopModule (
    input clk,
    input [7:0] in,
    output reg [7:0] anyedge
);

    reg [7:0] prev;

    always_ff @(posedge clk) begin
        anyedge <= prev ^ in;
        prev <= in;
    end

endmodule