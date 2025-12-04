module count_numbers(input reg [3:0] n, output reg [47:0] count);

  // Powers of 10 up to 10^13 (n in [1..15] => n-2 in [0..13])
  localparam P0  = 48'h000000000001; // 10^0
  localparam P1  = 48'h00000000000A; // 10^1
  localparam P2  = 48'h000000000064; // 10^2
  localparam P3  = 48'h000000003E8; // 10^3
  localparam P4  = 48'h00000002710; // 10^4
  localparam P5  = 48'h000000186A0; // 10^5
  localparam P6  = 48'h00000F4240;  // 10^6
  localparam P7  = 48'h0000989680;  // 10^7
  localparam P8  = 48'h0005F5E100;  // 10^8
  localparam P9  = 48'h03B9ACA000;  // 10^9
  localparam P10 = 48'h02540BE400;  // 10^10
  localparam P11 = 48'h174876E800;  // 10^11
  localparam P12 = 48'h0E8D4A51000; // 10^12
  localparam P13 = 48'h9184E72A000; // 10^13

  always @* begin
    case (n)
      4'd1:  count = 48'd1;                 // count = 1
      4'd2:  count = 48'd18;                // 18 * 10^0
      4'd3:  count = P1  * 48'd18;          // 18 * 10^1
      4'd4:  count = P2  * 48'd18;          // 18 * 10^2
      4'd5:  count = P3  * 48'd18;          // 18 * 10^3
      4'd6:  count = P4  * 48'd18;          // 18 * 10^4
      4'd7:  count = P5  * 48'd18;          // 18 * 10^5
      4'd8:  count = P6  * 48'd18;          // 18 * 10^6
      4'd9:  count = P7  * 48'd18;          // 18 * 10^7
      4'd10: count = P8  * 48'd18;          // 18 * 10^8
      4'd11: count = P9  * 48'd18;          // 18 * 10^9
      4'd12: count = P10 * 48'd18;          // 18 * 10^10
      4'd13: count = P11 * 48'd18;          // 18 * 10^11
      4'd14: count = P12 * 48'd18;          // 18 * 10^12
      4'd15: count = P13 * 48'd18;          // 18 * 10^13
      default: count = 48'd0;               // undefined n (outside 1..15)
    endcase
  end

endmodule