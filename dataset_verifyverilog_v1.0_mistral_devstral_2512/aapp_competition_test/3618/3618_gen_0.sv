module best_friend_pairs(
    input [1:0] n,
    output [29:0] result
);

    reg [29:0] result_reg;
    
    always @(*) begin
        case(n)
            2'b00: result_reg = 30'd10;      // n=1
            2'b01: result_reg = 30'd570;     // n=2
            2'b10: result_reg = 30'd46242;   // n=3
            default: result_reg = 30'd0;     // invalid input
        endcase
    end

    assign result = result_reg;

endmodule