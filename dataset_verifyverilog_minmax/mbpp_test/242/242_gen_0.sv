module char_counter(
  input [15:0][7:0] str_bytes,  // 16 bytes of ASCII characters with null termination
  output logic [3:0] count        // number of characters before null byte (0..15)
);

  // Parameter to represent the maximum count (15)
  parameter MAX_NIBBLE = 4'b1111;

  always @(*) begin
    count = 4'b0;                   // Default count is 0
    for (int i = 0; i < 16; i++) begin
      if (str_bytes[i] == 8'h00) begin
        // Null terminator found: output current index (number of non-null bytes before this)
        count = i[3:0];
        break;
      end else if (i == 15) begin
        // No null terminator found after checking all 16 bytes
        count = MAX_NIBBLE;
      end
    end
  end

endmodule