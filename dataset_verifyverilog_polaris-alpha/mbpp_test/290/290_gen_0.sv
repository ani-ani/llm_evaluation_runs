module max_list_finder(
  input  logic [3:0][3:0][4:0] lists,        // 4 lists, each with 4 elements of 5 bits
  input  logic [3:0][4:0]      valid_lengths, // 4 lengths, each in range 0-4 (use lower bits)
  output logic [1:0]           max_length,    // max valid length (0-4, truncated to 2 bits)
  output logic [3:0][4:0]      max_list       // selected list elements
);

  // Internal wires for effective lengths (clamped to 0-4, 3 bits is enough)
  logic [2:0] eff_len [3:0];

  // Clamp valid_lengths[i] to maximum of 4 (3'b100)
  assign eff_len[0] = (valid_lengths[0] > 5'd4) ? 3'd4 : valid_lengths[0][2:0];
  assign eff_len[1] = (valid_lengths[1] > 5'd4) ? 3'd4 : valid_lengths[1][2:0];
  assign eff_len[2] = (valid_lengths[2] > 5'd4) ? 3'd4 : valid_lengths[2][2:0];
  assign eff_len[3] = (valid_lengths[3] > 5'd4) ? 3'd4 : valid_lengths[3][2:0];

  // Find index of list with maximum effective length
  // Tie-breaking: first (lowest index) wins when lengths are equal
  logic [2:0] best_len;
  logic [1:0] best_idx;

  always_comb begin
    best_len = eff_len[0];
    best_idx = 2'd0;

    if (eff_len[1] > best_len) begin
      best_len = eff_len[1];
      best_idx = 2'd1;
    end

    if (eff_len[2] > best_len) begin
      best_len = eff_len[2];
      best_idx = 2'd2;
    end

    if (eff_len[3] > best_len) begin
      best_len = eff_len[3];
      best_idx = 2'd3;
    end
  end

  // Output max_length (2 bits; values above 3 will wrap as per spec)
  assign max_length = best_len[1:0];

  // Select the corresponding list as max_list (combinational mux)
  always_comb begin
    case (best_idx)
      2'd0: max_list = lists[0];
      2'd1: max_list = lists[1];
      2'd2: max_list = lists[2];
      2'd3: max_list = lists[3];
      default: max_list = '{default:5'b0};
    endcase
  end

endmodule