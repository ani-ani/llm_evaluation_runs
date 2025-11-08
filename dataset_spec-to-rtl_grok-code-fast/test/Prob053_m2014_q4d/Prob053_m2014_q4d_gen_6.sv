module TopModule(
    input clk,
    input in,
    output out
);
    reg q;
    assign out = q;
    wire d = in ^ q;
    always @(posedge clk) begin
        q <= d;
    end
endmodule