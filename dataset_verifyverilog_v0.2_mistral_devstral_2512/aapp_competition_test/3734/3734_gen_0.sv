module calendar_checker (
  input [31:0] day1_ascii,
  input [31:0] day2_ascii,
  output reg possible
);

  reg [2:0] day1, day2;
  integer diff;

  // Map ASCII strings to day numbers (0-6)
  always @(*) begin
    // Extract first 3 characters (24 bits)
    case (day1_ascii[23:0])
      24'h6E6F6D: day1 = 3'd0; // "mon"
      24'h657574: day1 = 3'd1; // "tue"
      24'h646577: day1 = 3'd2; // "wed"
      24'h756874: day1 = 3'd3; // "thu"
      24'h697266: day1 = 3'd4; // "fri"
      24'h746173: day1 = 3'd5; // "sat"
      24'h6E7573: day1 = 3'd6; // "sun"
      default: day1 = 3'd0; // default to Monday if invalid
    endcase

    case (day2_ascii[23:0])
      24'h6E6F6D: day2 = 3'd0; // "mon"
      24'h657574: day2 = 3'd1; // "tue"
      24'h646577: day2 = 3'd2; // "wed"
      24'h756874: day2 = 3'd3; // "thu"
      24'h697266: day2 = 3'd4; // "fri"
      24'h746173: day2 = 3'd5; // "sat"
      24'h6E7573: day2 = 3'd6; // "sun"
      default: day2 = 3'd0; // default to Monday if invalid
    endcase

    // Calculate difference modulo 7
    diff = (day2 - day1) % 7;

    // Check if difference matches possible month lengths
    possible = (diff == 0 || diff == 2 || diff == 3) ? 1'b1 : 1'b0;
  end

endmodule