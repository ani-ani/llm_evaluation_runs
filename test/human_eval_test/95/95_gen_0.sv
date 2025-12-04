module dict_case_checker #(
  parameter int MAX_KEYS  = 4,
  parameter int KEY_WIDTH = 8
) (
  input  logic [3:0]                 key_count,
  input  logic [MAX_KEYS-1:0][KEY_WIDTH-1:0] keys,
  output logic                       is_case_consistent
);

  // Per-key flags
  logic [MAX_KEYS-1:0] is_letter;
  logic [MAX_KEYS-1:0] is_upper;
  logic [MAX_KEYS-1:0] is_lower;
  logic [MAX_KEYS-1:0] is_valid_key;

  // Aggregate flags
  logic any_valid;
  logic all_letters;
  logic any_upper;
  logic any_lower;

  // Determine which key indices are valid based on key_count
  genvar i;
  generate
    for (i = 0; i < MAX_KEYS; i = i + 1) begin : GEN_KEY_CHECK
      // A key is valid if its index is less than key_count
      assign is_valid_key[i] = (key_count > i[3:0]);

      // Uppercase: 'A'(0x41) to 'Z'(0x5A)
      assign is_upper[i] = is_valid_key[i] &&
                           (keys[i] >= 8'h41) && (keys[i] <= 8'h5A);

      // Lowercase: 'a'(0x61) to 'z'(0x7A)
      assign is_lower[i] = is_valid_key[i] &&
                           (keys[i] >= 8'h61) && (keys[i] <= 8'h7A);

      // Letter if either upper or lower (only for valid keys)
      assign is_letter[i] = is_upper[i] || is_lower[i];
    end
  endgenerate

  // Combine per-key results (purely combinational)
  always_comb begin
    any_valid   = |is_valid_key;
    all_letters = 1'b1;
    any_upper   = 1'b0;
    any_lower   = 1'b0;

    for (int j = 0; j < MAX_KEYS; j++) begin
      if (is_valid_key[j]) begin
        if (!is_letter[j]) begin
          all_letters = 1'b0;
        end
        if (is_upper[j]) any_upper = 1'b1;
        if (is_lower[j]) any_lower = 1'b1;
      end
    end

    // Conditions:
    // - At least one valid key
    // - All valid keys are letters
    // - All letters are either all upper or all lower (not mixed)
    if (!any_valid) begin
      is_case_consistent = 1'b0;
    end else if (!all_letters) begin
      is_case_consistent = 1'b0;
    end else if (any_upper && any_lower) begin
      is_case_consistent = 1'b0;
    end else begin
      is_case_consistent = 1'b1;
    end
  end

endmodule