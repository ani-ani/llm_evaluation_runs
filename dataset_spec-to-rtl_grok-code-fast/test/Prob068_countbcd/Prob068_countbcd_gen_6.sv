module TopModule(
input clk,
input reset,
output reg [2:0] ena,
output reg [15:0] q
);
reg [3:0] ones_reg;
reg [3:0] tens_reg;
reg [3:0] hun_reg;
reg [3:0] thou_reg;
always @(posedge clk) begin
    if (reset) begin
        ones_reg <= 4'd0;
        tens_reg <= 4'd0;
        hun_reg <= 4'd0;
        thou_reg <= 4'd0;
        q <= 16'd0;
        ena <= 3'd0;
    end else begin
        logic carry_tens = (ones_reg == 9);
        logic carry_hun = (tens_reg == 9) && carry_tens;
        logic carry_thou = (hun_reg == 9) && carry_hun;
        // Update ones
        ones_reg <= (ones_reg == 9) ? 0 : ones_reg + 1;
        // Update tens
        if (carry_tens) begin
            tens_reg <= (tens_reg == 9) ? 0 : tens_reg + 1;
            ena[0] <= 1;
        end else begin
            ena[0] <= 0;
        end
        // Update hun
        if (carry_hun) begin
            hun_reg <= (hun_reg == 9) ? 0 : hun_reg + 1;
            ena[1] <= 1;
        end else begin
            ena[1] <= 0;
        end
        // Update thou
        if (carry_thou) begin
            thou_reg <= (thou_reg == 9) ? 0 : thou_reg + 1;
            ena[2] <= 1;
        end else begin
            ena[2] <= 0;
        end
        // Update q
        q <= {thou_reg, hun_reg, tens_reg, ones_reg};
    end
end
endmodule