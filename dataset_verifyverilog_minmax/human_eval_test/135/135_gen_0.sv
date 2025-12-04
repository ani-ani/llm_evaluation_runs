module can_arrange (
  input logic [7:0] arr [0:15],
  input logic [3:0] size,
  output logic [4:0] result
);

  always_comb begin
    result = 5'b11111; // Default to -1 representation
    
    // Only check if there are at least 2 elements
    if (size >= 2) begin
      for (int i = 1; i < 16; i++) begin
        if (i < size && arr[i] < arr[i-1]) begin
          result = i;
        end
      end
    end
  end

endmodule