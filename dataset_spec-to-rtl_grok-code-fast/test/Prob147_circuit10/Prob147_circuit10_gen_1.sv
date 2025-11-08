module TopModule(input clk, input a, input b, output state, output q);
    reg state_reg;
    reg prev_ab00;
    initial begin
        state_reg = 1'b0;
        prev_ab00 = 1'b1;
    end
    assign q = state_reg ? (a ~^ b) : (a ^ b);
    always @(posedge clk) begin
        if (a == 1'b0 && b == 1'b0) begin
            if (!prev_ab00) state_reg <= 1'b1;
            else state_reg <= 1'b0;
            prev_ab00 <= 1'b1;
        end else begin
            state_reg <= 1'b0;
            prev_ab00 <= 1'b0;
        end
    end
endmodule