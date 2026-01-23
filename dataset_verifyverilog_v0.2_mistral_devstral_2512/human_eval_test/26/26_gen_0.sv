module remove_duplicates (
  input [7:0] data_in [0:7],
  output [7:0] data_out [0:7]
);

  integer i, j;
  integer out_idx;
  reg [7:0] temp_out [0:7];
  reg [7:0] seen [0:7];

  always @* begin
    out_idx = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (data_in[i] != 8'hFF) begin
        // Check if current element is a duplicate
        integer is_duplicate = 0;
        for (j = 0; j < i; j = j + 1) begin
          if (data_in[j] == data_in[i]) begin
            is_duplicate = 1;
          end
        end
        
        // If not a duplicate, add to output
        if (!is_duplicate) begin
          temp_out[out_idx] = data_in[i];
          out_idx = out_idx + 1;
        end
      end
    end
    
    // Fill remaining positions with 255
    for (i = out_idx; i < 8; i = i + 1) begin
      temp_out[i] = 8'hFF;
    end
    
    // Assign to output
    for (i = 0; i < 8; i = i + 1) begin
      data_out[i] = temp_out[i];
    end
  end

endmodule