module longest_string(
  input [3:0] num_valid,
  input [7:0][63:0] strings,
  input [7:0][3:0] lengths,
  output reg [63:0] longest_str,
  output reg valid
);

  always_comb begin
    valid = (num_valid != 4'b0);
    if (num_valid == 4'b0) begin
      longest_str = 64'b0;
    end else begin
      reg [3:0] max_length = 4'b0;
      reg [63:0] max_string = 64'b0;
      for (int i = 0; i < 8; i++) begin
        if (i < num_valid) begin
          if (lengths[i] > max_length) begin
            max_length = lengths[i];
            max_string = strings[i];
          end
        end
      end
      longest_str = max_string;
    end
  end

endmodule