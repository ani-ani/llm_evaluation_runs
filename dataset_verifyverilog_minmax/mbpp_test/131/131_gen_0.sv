module reverse_vowels(
  input reg [7:0] string_length,
  input reg [7:0][7:0] chars_in,
  output logic [7:0][7:0] chars_out
);

  logic [7:0] vowels [8];
  logic [3:0] vowel_cnt;
  logic [3:0] rev_idx;
  integer i;

  always_comb begin
    // Initialize vowel count
    vowel_cnt = 0;
    // First pass: collect vowels
    for (i = 0; i < 8; i++) begin
      if (i < string_length) begin
        case (chars_in[i])
          8'h61, 8'h65, 8'h69, 8'h6F, 8'h75, 8'h41, 8'h45, 8'h49, 8'h4F, 8'h55: begin
            vowels[vowel_cnt] = chars_in[i];
            vowel_cnt = vowel_cnt + 1;
          end
          default: ;
        endcase
      end
    end
    // Second pass: reverse vowels in place
    rev_idx = vowel_cnt;
    for (i = 0; i < 8; i++) begin
      if (i < string_length) begin
        case (chars_in[i])
          8'h61, 8'h65, 8'h69, 8'h6F, 8'h75, 8'h41, 8'h45, 8'h49, 8'h4F, 8'h55: begin
            rev_idx = rev_idx - 1;
            chars_out[i] = vowels[rev_idx];
          end
          default: chars_out[i] = chars_in[i];
        endcase
      end else begin
        chars_out[i] = chars_in[i];
      end
    end
  end

endmodule