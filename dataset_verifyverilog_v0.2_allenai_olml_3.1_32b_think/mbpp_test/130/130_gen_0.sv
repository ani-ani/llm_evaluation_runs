module max_frequency(input [7:0] data_in [15:0], output reg [7:0] max_value, output reg [3:0] max_count);
  // Equality matrix computation
  wire [15:0][15:0] eq;
  generate
    for (int i=0; i<16; i++) begin
      for (int j=0; j<16; j++) begin
        eq[i][j] = (data_in[i] == data_in[j]);
      end
    end
  endgenerate

  // Count occurrences for each element
  wire [3:0] count [16:0];
  generate
    for (int i=0; i<16; i++) begin
      wire [3:0] s;
      assign s = 0;
      for (int j=0; j<16; j++) begin
        s = s + eq[i][j];
      end
      count[i] = s;
    end
  endgenerate

  // Find maximum count
  wire [3:0] max_count_val;
  wire [15:0] max_index;
  assign max_count_val = 0;
  assign max_index = 0;
  generate
    for (int i=1; i<16; i++) begin
      if (count[i] > max_count_val) begin
        max_count_val = count[i];
        max_index = i;
      end
    end
  endgenerate

  // Select smallest index for ties
  wire [15:0] candidate_indices;
  assign candidate_indices = 0;
  generate
    for (int i=0; i<16; i++) begin
      if (count[i] == max_count_val) begin
        candidate_indices = i;
      end
    end
  endgenerate

  // Find first set bit in candidate_indices
  wire [15:0] first_index;
  assign first_index = 0;
  assign first_index = candidate_indices[0] ? 0 : candidate_indices[1] ? 1 : candidate_indices[2] ? 2 : candidate_indices[3] ? 3 : candidate_indices[4] ? 4 : candidate_indices[5] ? 5 : candidate_indices[6] ? 6 : candidate_indices[7] ? 7 : candidate_indices[8] ? 8 : candidate_indices[9] ? 9 : candidate_indices[10] ? 10 : candidate_indices[11] ? 11 : candidate_indices[12] ? 12 : candidate_indices[13] ? 13 : candidate_indices[14] ? 14 : candidate_indices[15] ? 15 : 0;

  assign max_value = data_in[first_index];
  assign max_count = max_count_val;
endmodule