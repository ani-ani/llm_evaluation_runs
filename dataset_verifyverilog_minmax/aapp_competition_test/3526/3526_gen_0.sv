module answer_sequence_counter (
  input reg [2:0] n,
  input reg [3:0] m,
  input reg [111:0] hints_packed,
  output reg [31:0] valid_count
);
  
  // Parameters
  parameter MOD = 1000000007; // 0x3B9ACA07
  
  // Internal variables
  int unsigned count = 0;
  
  // Iterate over all possible answer sequences
  for (int seq = 0; seq < (1<<n); seq++) begin
    bit all_valid = 1'b1;
    
    // Check each hint
    for (int j = 0; j < m; j++) begin
      // Extract hint fields from packed hints
      logic [6:0] hint = hints_packed[j*7 +:7];
      logic [2:0] l = hint[6:4];
      logic [2:0] r = hint[3:1];
      logic type = hint[0];
      
      // Handle empty range (l > r)
      if (l > r) begin
        if (type == 1'b0) begin
          all_valid = 1'b0;
          break;
        end
      end else begin
        // Adjust range to valid problem indices [0, n-1]
        int first = l;
        int last = r;
        
        // Ensure range is within problem indices
        if (last > n-1) last = n-1;
        if (first < 0) first = 0;
        
        // Check if adjusted range is empty
        if (first > last) begin
          if (type == 1'b0) begin
            all_valid = 1'b0;
            break;
          end
        end else begin
          // Create mask for the range [first, last]
          int num_bits = last - first + 1;
          logic [7:0] mask = 8'b0;
          mask = ( (1 << num_bits) - 1 ) << first;
          
          // Extract answers in the range
          logic [7:0] bits_in_range = seq & mask;
          
          // Validate hint based on type
          if (type == 1'b1) begin
            // Same: all bits must be identical (0 or 1)
            if ( (bits_in_range != 0) && (bits_in_range != mask) ) begin
              all_valid = 1'b0;
              break;
            end
          end else begin
            // Different: must contain both 0 and 1
            if ( (bits_in_range == 0) || (bits_in_range == mask) ) begin
              all_valid = 1'b0;
              break;
            end
          end
        end
      end
    end
    
    // If all hints are valid, increment count
    if (all_valid) begin
      count = count + 1;
    end
  end
  
  // Apply modulo
  valid_count = count % MOD;
  
endmodule