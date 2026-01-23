module memory_game_expected (
    input wire [7:0] n,          // Number of pairs (1-8)
    output reg [31:0] expected   // Expected turns in Q16.16 format
);

// Combinational lookup table for expected turns
// Formula: E(n) = n + (2/3) * sum_{k=1}^{n-1} 1/k
// Values computed with high precision and converted to Q16.16 (16 integer, 16 fractional bits)
always @(*) begin
    case (n)
        8'd1:   expected = 32'h00010000;  // 1.000000000000
        8'd2:   expected = 32'h0002AAAB;  // 2.666666666667
        8'd3:   expected = 32'h00040000;  // 4.000000000000
        8'd4:   expected = 32'h00053804;  // 5.222222222222
        8'd5:   expected = 32'h0006637E;  // 6.388888888889
        8'd6:   expected = 32'h00078684;  // 7.522222222222
        8'd7:   expected = 32'h0008A296;  // 8.633333333333
        8'd8:   expected = 32'h00099991;  // 9.728571428571
        default: expected = 32'h00000000;  // 0 for N=0 or N>8
    endcase
end

endmodule