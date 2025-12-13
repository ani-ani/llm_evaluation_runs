module vowel_neighbor_count(
  input  [127:0] str_flat, // 16-byte string (ASCII), LSB=first char
  input  [3:0]   str_len,  // Actual string length (1-16)
  output [3:0]   count     // Number of qualifying characters
);

  // Function to check if a character is a lowercase vowel
  function automatic is_vowel(input [7:0] c);
    begin
      case (c)
        8'd97,   // 'a'
        8'd101,  // 'e'
        8'd105,  // 'i'
        8'd111,  // 'o'
        8'd117:  // 'u'
          is_vowel = 1'b1;
        default:
          is_vowel = 1'b0;
      endcase
    end
  endfunction

  // Extract characters into an array for easier indexing
  wire [7:0] chars [0:15];
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_CHARS
      assign chars[gi] = str_flat[8*gi +: 8];
    end
  endgenerate

  // Combinational count logic
  reg [4:0] cnt; // Up to 16, fits in 5 bits
  integer i;

  always @* begin
    cnt = 5'd0;

    // Only process when length > 0
    if (str_len != 4'd0) begin
      for (i = 0; i < 16; i = i + 1) begin
        if (i < str_len) begin
          // Current character must NOT be a vowel
          if (!is_vowel(chars[i])) begin
            // Determine neighbors within bounds
            if (i == 0) begin
              // First character: only right neighbor if it exists
              if (str_len > 1 && is_vowel(chars[1])) begin
                cnt = cnt + 1'b1;
              end
            end else if (i == (str_len - 1)) begin
              // Last character: only left neighbor
              if (is_vowel(chars[i-1])) begin
                cnt = cnt + 1'b1;
              end
            end else begin
              // Middle characters: check left or right neighbor
              if (is_vowel(chars[i-1]) || is_vowel(chars[i+1])) begin
                cnt = cnt + 1'b1;
              end
            end
          end
        end
      end
    end
  end

  assign count = cnt[3:0];

endmodule