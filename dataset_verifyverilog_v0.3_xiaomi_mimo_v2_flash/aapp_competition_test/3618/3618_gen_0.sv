module best_friend_pairs (
    input [1:0] n,
    output reg [29:0] result
);

    // Lookup table for n=1, 2, 3
    always @(*) begin
        case(n)
            2'b00: result = 30'd10;        // n=1
            2'b01: result = 30'd570;       // n=2
            2'b10: result = 30'd46242;     // n=3
            default: result = 30'd0;       // invalid input
        endcase
    end

endmodule