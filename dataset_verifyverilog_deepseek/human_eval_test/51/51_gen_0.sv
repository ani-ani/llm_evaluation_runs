module remove_vowels(input [127:0] text_in, output [127:0] text_out);
  wire [7:0] chars_in [0:15];
  wire [15:0] is_non_vowel;
  wire [4:0] prefix_count [0:15];
  wire [7:0] chars_out [0:15];
  genvar j, i;
  
  generate
    for (j=0; j<16; j=j+1) begin : in_slice
      assign chars_in[j] = text_in[j*8 +: 8];
    end
  endgenerate
  
  generate
    for (j=0; j<16; j=j+1) begin : non_vowel_detector
      assign is_non_vowel[j] = !(
        (chars_in[j] == 8'h61) || (chars_in[j] == 8'h41) ||
        (chars_in[j] == 8'h65) || (chars_in[j] == 8'h45) ||
        (chars_in[j] == 8'h69) || (chars_in[j] == 8'h49) ||
        (chars_in[j] == 8'h6F) || (chars_in[j] == 8'h4F) ||
        (chars_in[j] == 8'h75) || (chars_in[j] == 8'h55)
      );
    end
  endgenerate
  
  assign prefix_count[0] = 5'd0;
  generate
    for (j=1; j<16; j=j+1) begin : prefix_calc
      assign prefix_count[j] = prefix_count[j-1] + is_non_vowel[j-1];
    end
  endgenerate
  
  generate
    for (i=0; i<16; i=i+1) begin : output_byte
      wire [7:0] candidates [0:15];
      for (j=0; j<16; j=j+1) begin : candidate_sel
        assign candidates[j] = (prefix_count[j] == 5'(i) && is_non_vowel[j]) ? chars_in[j] : 8'h00;
      end
      assign chars_out[i] = candidates[0] | candidates[1] | candidates[2] | candidates[3] |
                            candidates[4] | candidates[5] | candidates[6] | candidates[7] |
                            candidates[8] | candidates[9] | candidates[10] | candidates[11] |
                            candidates[12] | candidates[13] | candidates[14] | candidates[15];
    end
  endgenerate
  
  generate
    for (j=0; j<16; j=j+1) begin : out_combine
      assign text_out[j*8 +:8] = chars_out[j];
    end
  endgenerate
endmodule