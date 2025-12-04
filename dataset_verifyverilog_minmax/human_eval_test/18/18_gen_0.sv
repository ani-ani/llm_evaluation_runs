module substring_counter (
  input [63:0] main_str,
  input [63:0] sub_str,
  input [3:0] main_len,
  input [3:0] sub_len,
  output logic [3:0] count
);

  genvar i;
  generate
    for (i=0; i<9; i++) begin : gen_match
      logic match_i;
      logic valid_i;
      logic match_cond;

      always @(*) begin
        if (sub_len == 0)
          match_i = 1'b0;
        else begin
          case (sub_len)
            1: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]);
            2: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]);
            3: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]);
            4: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]) &&
                       (main_str[39 - 8*i -: 8] == sub_str[39 -: 8]);
            5: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]) &&
                       (main_str[39 - 8*i -: 8] == sub_str[39 -: 8]) &&
                       (main_str[31 - 8*i -: 8] == sub_str[31 -: 8]);
            6: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]) &&
                       (main_str[39 - 8*i -: 8] == sub_str[39 -: 8]) &&
                       (main_str[31 - 8*i -: 8] == sub_str[31 -: 8]) &&
                       (main_str[23 - 8*i -: 8] == sub_str[23 -: 8]);
            7: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]) &&
                       (main_str[39 - 8*i -: 8] == sub_str[39 -: 8]) &&
                       (main_str[31 - 8*i -: 8] == sub_str[31 -: 8]) &&
                       (main_str[23 - 8*i -: 8] == sub_str[23 -: 8]) &&
                       (main_str[15 - 8*i -: 8] == sub_str[15 -: 8]);
            8: match_i = (main_str[63 - 8*i -: 8] == sub_str[63 -: 8]) && 
                       (main_str[55 - 8*i -: 8] == sub_str[55 -: 8]) &&
                       (main_str[47 - 8*i -: 8] == sub_str[47 -: 8]) &&
                       (main_str[39 - 8*i -: 8] == sub_str[39 -: 8]) &&
                       (main_str[31 - 8*i -: 8] == sub_str[31 -: 8]) &&
                       (main_str[23 - 8*i -: 8] == sub_str[23 -: 8]) &&
                       (main_str[15 - 8*i -: 8] == sub_str[15 -: 8]) &&
                       (main_str[7 - 8*i -: 8] == sub_str[7 -: 8]);
            default: match_i = 1'b0;
          endcase
        end
      end

      assign valid_i = (sub_len > 0) && (sub_len <= main_len) && (i <= main_len - sub_len);
      assign match_cond = valid_i ? match_i : 1'b0;
    end
  endgenerate

  assign count = gen_match[0].match_cond + gen_match[1].match_cond + gen_match[2].match_cond + 
                 gen_match[3].match_cond + gen_match[4].match_cond + gen_match[5].match_cond + 
                 gen_match[6].match_cond + gen_match[7].match_cond + gen_match[8].match_cond;

endmodule