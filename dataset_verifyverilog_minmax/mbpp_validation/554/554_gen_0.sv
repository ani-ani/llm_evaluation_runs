module filter_odds (
  input  logic [7:0] data  [0:7],
  output logic [7:0] result [0:7],
  output logic [7:0] valid_mask
);
  always_comb begin
    logic [2:0] odd_count;
    logic [7:0] temp_result [0:7];

    // Filter odd values and pack them contiguously at the start
    odd_count = 3'd0;
    for (int i = 0; i < 8; i++) begin
      if (data[i][0]) begin // odd number (LSB == 1)
        temp_result[odd_count] = data[i];
        odd_count++;
      end
    end

    // Fill the rest of the result array with zeros
    for (int j = 0; j < 8; j++) begin
      if (j < odd_count) begin
        result[j] = temp_result[j];
      end else begin
        result[j] = 8'b0;
      end
    end

    // valid_mask has 1s in positions [0:odd_count-1]
    valid_mask = (odd_count == 0) ? 8'b0 : (8'b1 << odd_count) - 1;
  end
endmodule