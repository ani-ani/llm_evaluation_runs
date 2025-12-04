module returnable_rooms_counter (
  input [15:0] belt_states,
  output logic [3:0] count
);
  // Extract 2-bit belt states: 0..7 -> belt[0] is LSBs of belt_states[1:0]
  logic [1:0] belt [0:7];
  for (genvar i = 0; i < 8; i++) begin : b2s
    assign belt[i] = belt_states[2*i+:2];
  end

  // Invalid 2-bit codes mask (only 00/01/10 are valid)
  logic [7:0] invalid_mask;
  for (genvar i = 0; i < 8; i++) begin : inv
    assign invalid_mask[i] = (belt[i] == 2'b11);
  end

  // Uniform case: all 01 or all 10 (count becomes 8)
  logic all_eq_01, all_eq_10;
  assign all_eq_01 = (belt[0] == 2'b01) && (belt[1] == 2'b01) && (belt[2] == 2'b01) &&
                     (belt[3] == 2'b01) && (belt[4] == 2'b01) && (belt[5] == 2'b01) &&
                     (belt[6] == 2'b01) && (belt[7] == 2'b01);
  assign all_eq_10 = (belt[0] == 2'b10) && (belt[1] == 2'b10) && (belt[2] == 2'b10) &&
                     (belt[3] == 2'b10) && (belt[4] == 2'b10) && (belt[5] == 2'b10) &&
                     (belt[6] == 2'b10) && (belt[7] == 2'b10);
  logic uniform_case;
  assign uniform_case = all_eq_01 | all_eq_10;

  // Combinational count of returnable rooms
  logic [3:0] cnt;
  always_comb begin
    cnt = 4'd0;
    for (int i = 0; i < 8; i++) begin
      int iprev;
      iprev = (i == 0) ? 7 : i - 1;
      logic [1:0] prev;
      logic prevValid;
      logic currValid;
      logic validCurrPrev, validPrev;
      logic ret;

      prev = belt[iprev];
      currValid = ~invalid_mask[i];
      prevValid = ~invalid_mask[iprev];
      // Mask out invalid codes to avoid 'x' in comparisons
      validCurrPrev = currValid ? belt[i] : 2'b00;
      validPrev     = prevValid ? prev     : 2'b00;

      // Room i is returnable if belt[i] == '-' (00) OR belt[i-1] == '-'
      ret = (validCurrPrev == 2'b00) || (validPrev == 2'b00);

      if (ret && currValid) cnt++;
    end
  end

  // Apply uniform-case override
  always_comb begin
    if (uniform_case) count = 4'd8;
    else              count = cnt;
  end
endmodule