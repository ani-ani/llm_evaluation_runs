module max_valid_int (
  input reg [7:0] data [0:7], // 8-element array of 8-bit values (LSB corresponds to data[0])
  input reg [7:0] valid_mask,  // Bitmask: 1=valid, 0=invalid (LSB -> data[0])
  output reg [7:0] max_val     // Maximum among valid entries; 0 if none valid
);

  integer i;
  always_comb begin
    max_val = 8'h0; // Default: no valid entries
    for (i = 0; i < 8; i = i + 1) begin
      if (valid_mask[i] && (data[i] > max_val)) begin
        max_val = data[i];
      end
    end
  end

endmodule