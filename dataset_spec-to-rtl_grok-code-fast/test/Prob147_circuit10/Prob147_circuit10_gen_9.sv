module TopModule(
    input clk,
    input a,
    input b,
    output reg state,
    output q
);
    assign q = a ^ b ^ state;
    always @(posedge clk) begin
        if (a == 1'b1 && b == 1'b1) begin
            state <= ~state;
        end else if (a == 1'b0 && b == 1'b0) begin
            state <= 1'b0;
        end else begin
            state <= state;
        end
    end
endmodule