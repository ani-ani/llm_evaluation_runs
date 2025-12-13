module dict_merger(
  input  [2:0][7:0] key_in1,
  input  [2:0][7:0] key_in2,
  input  [2:0][7:0] key_in3,
  input  [2:0][3:0] val_in1,
  input  [2:0][3:0] val_in2,
  input  [2:0][3:0] val_in3,
  input  [2:0]       valid1,
  input  [2:0]       valid2,
  input  [2:0]       valid3,
  output [7:0][7:0]  merged_keys,
  output [7:0][3:0]  merged_vals,
  output [7:0]       merged_valid
);

  // Internal structures: unsorted unique set from all dicts
  reg [7:0] unique_keys [7:0];
  reg [2:0] unique_count;

  integer i, j;
  reg found;

  // Track which keys exist in each dict
  reg present1 [7:0];
  reg present2 [7:0];
  reg present3 [7:0];

  // Priority selected value per unique key
  reg [3:0] sel_val [7:0];

  // Assign outputs from internal arrays
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : OUT_ASSIGN
      assign merged_keys[gi]  = unique_keys[gi];
      assign merged_vals[gi]  = sel_val[gi];
      assign merged_valid[gi] = (gi < unique_count) ? 1'b1 : 1'b0;
    end
  endgenerate

  // Combinational logic to build unique key list and select values
  always @* begin
    // Initialize
    unique_count = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
      unique_keys[i] = 8'd0;
      sel_val[i]     = 4'd0;
      present1[i]    = 1'b0;
      present2[i]    = 1'b0;
      present3[i]    = 1'b0;
    end

    // Helper task-like behavior: insert key if new
    // Dict1
    for (i = 0; i < 3; i = i + 1) begin
      if (valid1[i]) begin
        found = 1'b0;
        for (j = 0; j < unique_count; j = j + 1) begin
          if (unique_keys[j] == key_in1[i]) begin
            found = 1'b1;
          end
        end
        if (!found && (unique_count < 8)) begin
          unique_keys[unique_count] = key_in1[i];
          unique_count = unique_count + 1'b1;
        end
      end
    end

    // Dict2
    for (i = 0; i < 3; i = i + 1) begin
      if (valid2[i]) begin
        found = 1'b0;
        for (j = 0; j < unique_count; j = j + 1) begin
          if (unique_keys[j] == key_in2[i]) begin
            found = 1'b1;
          end
        end
        if (!found && (unique_count < 8)) begin
          unique_keys[unique_count] = key_in2[i];
          unique_count = unique_count + 1'b1;
        end
      end
    end

    // Dict3
    for (i = 0; i < 3; i = i + 1) begin
      if (valid3[i]) begin
        found = 1'b0;
        for (j = 0; j < unique_count; j = j + 1) begin
          if (unique_keys[j] == key_in3[i]) begin
            found = 1'b1;
          end
        end
        if (!found && (unique_count < 8)) begin
          unique_keys[unique_count] = key_in3[i];
          unique_count = unique_count + 1'b1;
        end
      end
    end

    // For each unique key, determine presence in each dict and choose value by priority
    for (j = 0; j < 8; j = j + 1) begin
      present1[j] = 1'b0;
      present2[j] = 1'b0;
      present3[j] = 1'b0;
      sel_val[j]  = 4'd0;

      if (j < unique_count) begin
        // Check dict1
        for (i = 0; i < 3; i = i + 1) begin
          if (valid1[i] && (key_in1[i] == unique_keys[j])) begin
            present1[j] = 1'b1;
            sel_val[j] = val_in1[i];
          end
        end

        // Check dict2 only if not in dict1
        if (!present1[j]) begin
          for (i = 0; i < 3; i = i + 1) begin
            if (valid2[i] && (key_in2[i] == unique_keys[j])) begin
              present2[j] = 1'b1;
              sel_val[j] = val_in2[i];
            end
          end
        end

        // Check dict3 only if not in dict1 or dict2
        if (!present1[j] && !present2[j]) begin
          for (i = 0; i < 3; i = i + 1) begin
            if (valid3[i] && (key_in3[i] == unique_keys[j])) begin
              present3[j] = 1'b1;
              sel_val[j] = val_in3[i];
            end
          end
        end
      end
    end
  end

endmodule