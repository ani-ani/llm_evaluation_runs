module TopModule(
    input clk,
    input reset,
    output [2:0] ena,
    output [15:0] q
);

reg [3:0] ones, tens, hundreds, thousands;

assign q = {thousands, hundreds, tens, ones};
assign ena[0] = (ones == 4'd9);
assign ena[1] = (ones == 4'd9 && tens == 4'd9);
assign ena[2] = (ones == 4'd9 && tens == 4'd9 && hundreds == 4'd9);

always @(posedge clk) begin
    if (reset) begin
        ones <= 4'd0;
        tens <= 4'd0;
        hundreds <= 4'd0;
        thousands <= 4'd0;
    end else begin
        if (ones == 9) begin
            ones <= 0;
            if (tens == 9) begin
                tens <= 0;
                if (hundreds == 9) begin
                    hundreds <= 0;
                    if (thousands == 9) begin
                        thousands <= 0;
                    end else begin
                        thousands <= thousands + 1;
                    end
                end else begin
                    hundreds <= hundreds + 1;
                end
            end else begin
                tens <= tens + 1;
            end
        end else begin
            ones <= ones + 1;
        end
    end
end

endmodule