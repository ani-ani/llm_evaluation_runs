module interval_prime_check(
  input  signed [7:0] a_start,
  input  signed [7:0] a_end,
  input  signed [7:0] b_start,
  input  signed [7:0] b_end,
  output        prime_found
);

  // Intersection start = max(a_start, b_start)
  wire signed [7:0] inter_start = (a_start >= b_start) ? a_start : b_start;

  // Intersection end = min(a_end, b_end)
  wire signed [7:0] inter_end   = (a_end <= b_end) ? a_end : b_end;

  // Check for valid intersection
  wire has_intersection = (inter_start <= inter_end);

  // Compute length as unsigned magnitude: len = inter_end - inter_start
  // Using 9 bits to avoid overflow in intermediate subtraction
  wire signed [8:0] len_signed = inter_end - inter_start;
  wire       [7:0] len        = len_signed[7:0];

  // Hardcoded prime LUT for 0-255
  reg prime_lut;
  always @* begin
    case (len)
      8'd2,   8'd3,   8'd5,   8'd7,
      8'd11,  8'd13,  8'd17,  8'd19,
      8'd23,  8'd29,  8'd31,  8'd37,
      8'd41,  8'd43,  8'd47,  8'd53,
      8'd59,  8'd61,  8'd67,  8'd71,
      8'd73,  8'd79,  8'd83,  8'd89,
      8'd97,  8'd101, 8'd103, 8'd107,
      8'd109, 8'd113, 8'd127, 8'd131,
      8'd137, 8'd139, 8'd149, 8'd151,
      8'd157, 8'd163, 8'd167, 8'd173,
      8'd179, 8'd181, 8'd191, 8'd193,
      8'd197, 8'd199, 8'd211, 8'd223,
      8'd227, 8'd229, 8'd233, 8'd239,
      8'd241, 8'd251:
        prime_lut = 1'b1;
      default:
        prime_lut = 1'b0;
    endcase
  end

  assign prime_found = has_intersection & prime_lut;

endmodule