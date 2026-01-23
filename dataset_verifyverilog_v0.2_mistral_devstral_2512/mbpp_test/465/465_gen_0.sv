module drop_empty (
  input [7:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
  input [7:0] val_0, val_1, val_2, val_3, val_4, val_5, val_6, val_7,
  output reg [7:0] out_key_0, out_key_1, out_key_2, out_key_3,
  output reg [7:0] out_val_0, out_val_1, out_val_2, out_val_3,
  output reg [2:0] count
);

  reg [7:0] keys [0:7] = '{key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7};
  reg [7:0] vals [0:7] = '{val_0, val_1, val_2, val_3, val_4, val_5, val_6, val_7};
  reg [7:0] filtered_keys [0:7];
  reg [7:0] filtered_vals [0:7];
  integer i, j;

  // Initialize outputs
  for (i = 0; i < 8; i = i + 1) begin
    filtered_keys[i] = 8'b0;
    filtered_vals[i] = 8'b0;
  end

  // Filter non-None pairs
  j = 0;
  for (i = 0; i < 8; i = i + 1) begin
    if (vals[i] !== 8'hFF) begin
      filtered_keys[j] = keys[i];
      filtered_vals[j] = vals[i];
      j = j + 1;
    end
  end

  // Assign outputs
  out_key_0 = filtered_keys[0];
  out_key_1 = filtered_keys[1];
  out_key_2 = filtered_keys[2];
  out_key_3 = filtered_keys[3];
  out_val_0 = filtered_vals[0];
  out_val_1 = filtered_vals[1];
  out_val_2 = filtered_vals[2];
  out_val_3 = filtered_vals[3];
  count = j;

endmodule