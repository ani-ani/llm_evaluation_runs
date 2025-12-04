module substring_counter(
  input [63:0] main_str,
  input [63:0] sub_str,
  input [3:0] main_len,
  input [3:0] sub_len,
  output reg [3:0] count
);

  wire [7:0] main_bytes [0:7];
  wire [7:0] sub_bytes [0:7];

  generate
    genvar b;
    for (b=0; b<8; b++) begin : decomp
      assign main_bytes[b] = main_str[64 - 8*b -: 8];
      assign sub_bytes[b] = sub_str[64 - 8*b -: 8];
    end
  endgenerate

  wire [7:0] j_lt_sub;

  generate
    genvar j_idx;
    for (j_idx=0; j_idx<8; j_idx++) begin : j_lt_sub_gen
      assign j_lt_sub[j_idx] = (j_idx < sub_len);
    end
  endgenerate

  wire [7:0] matches;

  generate
    genvar i_idx;
    for (i_idx=0; i_idx<8; i_idx++) begin : position
      wire valid;
      assign valid = (sub_len != 4'b0) && (sub_len <= main_len) && (i_idx <= (main_len - sub_len));

      wire [7:0] match_bits;
      genvar j;
      for (j=0; j<8; j++) begin : byte_comp
        wire [7:0] main_byte_val;
        assign main_byte_val = ((i_idx + j) < 8) ? main_bytes[i_idx + j] : 8'b0;
        wire byte_eq = (main_byte_val == sub_bytes[j]);
        assign match_bits[j] = j_lt_sub[j] ? byte_eq : 1'b1;
      end

      assign matches[i_idx] = valid && (&match_bits);
    end
  endgenerate

  always_comb begin
    count = 4'b0;
    for (int i=0; i<8; i++) begin
      count += matches[i];
    end
  end

endmodule