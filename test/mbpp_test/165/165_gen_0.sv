module char_position_counter(
  input  [7:0] str [0:7],
  output [3:0] count
);

  wire [7:0] exp_upper [0:7];
  wire [7:0] exp_lower [0:7];
  wire [7:0] str_upper [0:7];
  wire [7:0] str_lower [0:7];
  wire [7:0] match;

  // Expected characters for positions 0-7
  // 'A' = 8'h41, 'a' = 8'h61
  assign exp_upper[0] = 8'h41; // 'A'
  assign exp_lower[0] = 8'h61; // 'a'
  assign exp_upper[1] = 8'h42; // 'B'
  assign exp_lower[1] = 8'h62; // 'b'
  assign exp_upper[2] = 8'h43; // 'C'
  assign exp_lower[2] = 8'h63; // 'c'
  assign exp_upper[3] = 8'h44; // 'D'
  assign exp_lower[3] = 8'h64; // 'd'
  assign exp_upper[4] = 8'h45; // 'E'
  assign exp_lower[4] = 8'h65; // 'e'
  assign exp_upper[5] = 8'h46; // 'F'
  assign exp_lower[5] = 8'h66; // 'f'
  assign exp_upper[6] = 8'h47; // 'G'
  assign exp_lower[6] = 8'h67; // 'g'
  assign exp_upper[7] = 8'h48; // 'H'
  assign exp_lower[7] = 8'h68; // 'h'

  // Precompute case-flipped versions for each character
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_case
      assign str_upper[i] = {str[i][7:5], 1'b0, str[i][3:0]}; // clear bit5
      assign str_lower[i] = {str[i][7:5], 1'b1, str[i][3:0]}; // set bit5
    end
  endgenerate

  // Match if equals expected upper or expected lower
  assign match[0] = (str[i=0] == exp_upper[0]) || (str[i=0] == exp_lower[0]);
  assign match[1] = (str[1]   == exp_upper[1]) || (str[1]   == exp_lower[1]);
  assign match[2] = (str[2]   == exp_upper[2]) || (str[2]   == exp_lower[2]);
  assign match[3] = (str[3]   == exp_upper[3]) || (str[3]   == exp_lower[3]);
  assign match[4] = (str[4]   == exp_upper[4]) || (str[4]   == exp_lower[4]);
  assign match[5] = (str[5]   == exp_upper[5]) || (str[5]   == exp_lower[5]);
  assign match[6] = (str[6]   == exp_upper[6]) || (str[6]   == exp_lower[6]);
  assign match[7] = (str[7]   == exp_upper[7]) || (str[7]   == exp_lower[7]);

  // Population count of match[7:0]
  wire [3:0] s0 = match[0] + match[1];
  wire [3:0] s1 = match[2] + match[3];
  wire [3:0] s2 = match[4] + match[5];
  wire [3:0] s3 = match[6] + match[7];

  wire [4:0] s4 = s0 + s1;
  wire [4:0] s5 = s2 + s3;

  assign count = s4 + s5; // max 8, fits in 4 bits

endmodule