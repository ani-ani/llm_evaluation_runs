module costume_parity_solver (
  input [2:0] n,
  input [2:0] l_array[0:7],
  input [2:0] r_array[0:7],
  input [7:0] x_array,
  output reg [31:0] result
);

always_comb begin
  integer i, j, s_int;
  logic [31:0] count = 0;
  logic [7:0] s;
  logic valid;
  logic [2:0] start[0:7];
  logic [2:0] end_[0:7];
  logic segment_parity;

  // Precompute start and end indices for each child i
  for (i=0; i<8; i++) begin
    if (i < n) begin
      start[i] = (i - l_array[i] + n) % n;
      end_[i] = (i + r_array[i]) % n;
    end
    else begin
      start[i] = 0;
      end_[i] = 0;
    end
  end

  // Iterate over all possible 8-bit assignments
  for (s_int=0; s_int<256; s_int++) begin
    s = s_int;
    valid = 1'b1;
    // Check each child i in the ring (0 to n-1)
    for (i=0; i<8; i++) begin
      if (i < n) begin
        segment_parity = 1'b0;
        // Check each index j in 0..7, but only include if j < n and in segment
        for (j=0; j<8; j++) begin
          if (j < n) begin
            if ( (start[i] <= end_[i]) ) begin
              if (j >= start[i] && j <= end_[i]) begin
                segment_parity ^= s[j];
              end
            end else begin
              if (j >= start[i] || j <= end_[i]) begin
                segment_parity ^= s[j];
              end
            end
          end
        end
        // Compare to x_array[i]
        if (segment_parity != x_array[i]) begin
          valid = 1'b0;
        end
      end
    end
    if (valid) begin
      count = count + 32'd1;
    end
  end

  // Apply modulo 1000000007
  result = count % 32'd1000000007;
end

endmodule