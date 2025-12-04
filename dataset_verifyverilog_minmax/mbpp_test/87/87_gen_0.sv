module dict_merger (
  input [2:0][7:0] key_in1, key_in2, key_in3,
  input [2:0][3:0] val_in1, val_in2, val_in3,
  input [2:0]       valid1, valid2, valid3,

  output logic [7:0][7:0] merged_keys,
  output logic [7:0][3:0] merged_vals,
  output logic [7:0]      merged_valid
);

  // Constants for clarity
  localparam DICT1 = 3'd1;
  localparam DICT2 = 3'd2;
  localparam DICT3 = 3'd3;

  logic [2:0][7:0] keys [3];
  logic [2:0][3:0] vals [3];
  logic [2:0]      valids [3];
  logic [2:0]      prio   [3];

  assign keys[0]  = key_in1;
  assign vals[0]  = val_in1;
  assign valids[0]= valid1;
  assign prio[0]  = DICT1;

  assign keys[1]  = key_in2;
  assign vals[1]  = val_in2;
  assign valids[1]= valid2;
  assign prio[1]  = DICT2;

  assign keys[2]  = key_in3;
  assign vals[2]  = val_in3;
  assign valids[2]= valid3;
  assign prio[2]  = DICT3;

  integer i, j, k;

  // Initialize outputs (combinational)
  always_comb begin
    for (i = 0; i < 8; i++) begin
      merged_keys[i]  = 8'h0;
      merged_vals[i]  = 4'h0;
      merged_valid[i] = 1'b0;
    end

    // Merge with priority: dict1 > dict2 > dict3
    for (i = 0; i < 3; i++) begin
      for (j = 0; j < 3; j++) begin
        if (valids[i][j]) begin
          // Try to find existing key
          for (k = 0; k < 8; k++) begin
            if (merged_valid[k] && (merged_keys[k] == keys[i][j])) begin
              // Collision: keep highest priority value
              if (prio[i] > prio[k]) begin
                merged_vals[k] = vals[i][j];
              end
              break; // done searching
            end
          end
          // Not found: add new entry
          if (k == 8) begin
            for (k = 0; k < 8; k++) begin
              if (!merged_valid[k]) begin
                merged_keys[k]  = keys[i][j];
                merged_vals[k]  = vals[i][j];
                merged_valid[k] = 1'b1;
                break;
              end
            end
          end
        end
      end
    end
  end

endmodule
