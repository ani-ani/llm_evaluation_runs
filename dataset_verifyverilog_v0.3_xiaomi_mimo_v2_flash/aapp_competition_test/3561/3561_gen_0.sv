module wolf_sheep_cabbage (
    input [31:0] W,
    input [31:0] S,
    input [31:0] C,
    input [31:0] K,
    output reg result
);
    // Condition: YES if S == 0 OR (K >= S AND W + C <= 2*K)
    always @(*) begin
        if (S == 32'd0) begin
            result = 1'b1;
        end else if ((K >= S) && ((W + C) <= (K << 1))) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end
endmodule