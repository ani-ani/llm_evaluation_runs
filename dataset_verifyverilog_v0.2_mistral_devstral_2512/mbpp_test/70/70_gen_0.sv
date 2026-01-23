module tuple_length_checker (
  input [3:0] valid_tuples_count,
  input [3:0] tuple_lengths [0:3],
  output reg equal
);

  always @(*) begin
    equal = 1'b1;
    
    if (valid_tuples_count <= 1) begin
      equal = 1'b1;
    end
    else begin
      for (int i = 1; i < valid_tuples_count; i = i + 1) begin
        if (tuple_lengths[i] != tuple_lengths[0]) begin
          equal = 1'b0;
        end
      end
    end
  end

endmodule