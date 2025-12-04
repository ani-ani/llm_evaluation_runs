module bidirectional_counter(
  input [7:0] tuples [0:7], // Array of 8 tuples, each tuple = {element1[7:0], element0[7:0]}
  output reg [4:0] count // Number of bidirectional pairs (0..28)
);

  // Generate and sum all 28 unique pair matches (i < j)
  wire [27:0] pair_match;
  assign pair_match[0]  = (tuples[0][15:8] == tuples[1][7:0])  && (tuples[0][7:0]  == tuples[1][15:8]);
  assign pair_match[1]  = (tuples[0][15:8] == tuples[2][7:0])  && (tuples[0][7:0]  == tuples[2][15:8]);
  assign pair_match[2]  = (tuples[0][15:8] == tuples[3][7:0])  && (tuples[0][7:0]  == tuples[3][15:8]);
  assign pair_match[3]  = (tuples[0][15:8] == tuples[4][7:0])  && (tuples[0][7:0]  == tuples[4][15:8]);
  assign pair_match[4]  = (tuples[0][15:8] == tuples[5][7:0])  && (tuples[0][7:0]  == tuples[5][15:8]);
  assign pair_match[5]  = (tuples[0][15:8] == tuples[6][7:0])  && (tuples[0][7:0]  == tuples[6][15:8]);
  assign pair_match[6]  = (tuples[0][15:8] == tuples[7][7:0])  && (tuples[0][7:0]  == tuples[7][15:8]);
  assign pair_match[7]  = (tuples[1][15:8] == tuples[2][7:0])  && (tuples[1][7:0]  == tuples[2][15:8]);
  assign pair_match[8]  = (tuples[1][15:8] == tuples[3][7:0])  && (tuples[1][7:0]  == tuples[3][15:8]);
  assign pair_match[9]  = (tuples[1][15:8] == tuples[4][7:0])  && (tuples[1][7:0]  == tuples[4][15:8]);
  assign pair_match[10] = (tuples[1][15:8] == tuples[5][7:0])  && (tuples[1][7:0]  == tuples[5][15:8]);
  assign pair_match[11] = (tuples[1][15:8] == tuples[6][7:0])  && (tuples[1][7:0]  == tuples[6][15:8]);
  assign pair_match[12] = (tuples[1][15:8] == tuples[7][7:0])  && (tuples[1][7:0]  == tuples[7][15:8]);
  assign pair_match[13] = (tuples[2][15:8] == tuples[3][7:0])  && (tuples[2][7:0]  == tuples[3][15:8]);
  assign pair_match[14] = (tuples[2][15:8] == tuples[4][7:0])  && (tuples[2][7:0]  == tuples[4][15:8]);
  assign pair_match[15] = (tuples[2][15:8] == tuples[5][7:0])  && (tuples[2][7:0]  == tuples[5][15:8]);
  assign pair_match[16] = (tuples[2][15:8] == tuples[6][7:0])  && (tuples[2][7:0]  == tuples[6][15:8]);
  assign pair_match[17] = (tuples[2][15:8] == tuples[7][7:0])  && (tuples[2][7:0]  == tuples[7][15:8]);
  assign pair_match[18] = (tuples[3][15:8] == tuples[4][7:0])  && (tuples[3][7:0]  == tuples[4][15:8]);
  assign pair_match[19] = (tuples[3][15:8] == tuples[5][7:0])  && (tuples[3][7:0]  == tuples[5][15:8]);
  assign pair_match[20] = (tuples[3][15:8] == tuples[6][7:0])  && (tuples[3][7:0]  == tuples[6][15:8]);
  assign pair_match[21] = (tuples[3][15:8] == tuples[7][7:0])  && (tuples[3][7:0]  == tuples[7][15:8]);
  assign pair_match[22] = (tuples[4][15:8] == tuples[5][7:0])  && (tuples[4][7:0]  == tuples[5][15:8]);
  assign pair_match[23] = (tuples[4][15:8] == tuples[6][7:0])  && (tuples[4][7:0]  == tuples[6][15:8]);
  assign pair_match[24] = (tuples[4][15:8] == tuples[7][7:0])  && (tuples[4][7:0]  == tuples[7][15:8]);
  assign pair_match[25] = (tuples[5][15:8] == tuples[6][7:0])  && (tuples[5][7:0]  == tuples[6][15:8]);
  assign pair_match[26] = (tuples[5][15:8] == tuples[7][7:0])  && (tuples[5][7:0]  == tuples[7][15:8]);
  assign pair_match[27] = (tuples[6][15:8] == tuples[7][7:0])  && (tuples[6][7:0]  == tuples[7][15:8]);

  // Sum all 28 results; result fits in 5 bits (max 28)
  wire [4:0] sum;
  assign sum =
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[0]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[1]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[2]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[3]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[4]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[5]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[6]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[7]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[8]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[9]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[10]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[11]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[12]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[13]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[14]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[15]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[16]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[17]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[18]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[19]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[20]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[21]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[22]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[23]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[24]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[25]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[26]} +
    {1'b0, 1'b0, 1'b0, 1'b0, pair_match[27]};

  assign count = sum;
endmodule