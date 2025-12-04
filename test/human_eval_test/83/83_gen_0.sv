module count_numbers(
  input  [3:0]  n,
  output reg [47:0] count
);

  always @* begin
    case (n)
      4'd1:  count = 48'd1;                    // 1
      4'd2:  count = 48'd18;                   // 18 * 10^0
      4'd3:  count = 48'd180;                  // 18 * 10^1
      4'd4:  count = 48'd1800;                 // 18 * 10^2
      4'd5:  count = 48'd18000;                // 18 * 10^3
      4'd6:  count = 48'd180000;               // 18 * 10^4
      4'd7:  count = 48'd1800000;              // 18 * 10^5
      4'd8:  count = 48'd18000000;             // 18 * 10^6
      4'd9:  count = 48'd180000000;            // 18 * 10^7
      4'd10: count = 48'd1800000000;           // 18 * 10^8
      4'd11: count = 48'd18000000000;          // 18 * 10^9
      4'd12: count = 48'd180000000000;         // 18 * 10^10
      4'd13: count = 48'd1800000000000;        // 18 * 10^11
      4'd14: count = 48'd18000000000000;       // 18 * 10^12
      4'd15: count = 48'd180000000000000;      // 18 * 10^13
      default: count = 48'd0;                  // out-of-range safeguard
    endcase
  end

endmodule