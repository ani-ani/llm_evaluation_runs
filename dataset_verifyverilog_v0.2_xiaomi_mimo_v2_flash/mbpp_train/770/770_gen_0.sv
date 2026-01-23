module odd_fourth_power_sum (
    input [3:0] n,
    output reg [31:0] sum
);

    always @(*) begin
        case (n)
            4'd0: sum = 32'd0;
            4'd1: sum = 32'd1;                      // 1^4
            4'd2: sum = 32'd82;                     // 1^4 + 3^4
            4'd3: sum = 32'd707;                    // ... + 5^4
            4'd4: sum = 32'd3108;                   // ... + 7^4
            4'd5: sum = 32'd9793;                   // ... + 9^4
            4'd6: sum = 32'd24562;                  // ... + 11^4
            4'd7: sum = 32'd52587;                  // ... + 13^4
            4'd8: sum = 32'd101708;                 // ... + 15^4
            default: sum = 32'd0;                   // Default case
        endcase
    end

endmodule
