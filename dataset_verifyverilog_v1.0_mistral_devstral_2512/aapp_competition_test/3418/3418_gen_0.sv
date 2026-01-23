module lucky_numbers (
    input [9:0] n,
    output reg [15:0] supply
);
    // Lookup table for n-digit lucky numbers (polydivisible numbers)
    // Only valid for n=1 to 8; for n>8, output 0
    always @(*) begin
        case(n)
            10'd1: supply = 16'd9;
            10'd2: supply = 16'd45;
            10'd3: supply = 16'd150;
            10'd4: supply = 16'd375;
            10'd5: supply = 16'd750;
            10'd6: supply = 16'd1200;
            10'd7: supply = 16'd1713;
            10'd8: supply = 16'd2227;
            default: supply = 16'd0;
        endcase
    end
endmodule