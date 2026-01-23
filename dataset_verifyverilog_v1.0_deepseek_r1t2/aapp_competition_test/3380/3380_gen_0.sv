module probability(
    input [7:0] N,
    output reg [31:0] prob
);
    always @(*) begin
        case (N)
            8'd2: prob = 32'hFFFFFFFF;
            8'd3: prob = 32'hFFFFFFFF;
            8'd4: prob = 32'hF672B0A6;
            8'd5: prob = 32'hEBEDFA58;
            8'd6: prob = 32'hE246D38C;
            8'd7: prob = 32'hD93A5C66;
            8'd8: prob = 32'hD03A5C64;
            default: prob = 32'd0;
        endcase
    end
endmodule