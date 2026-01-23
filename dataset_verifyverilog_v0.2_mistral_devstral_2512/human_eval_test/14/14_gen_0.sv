module all_prefixes (
  input [7:0][7:0] input_string,
  input [2:0] input_length,
  output reg [7:0][7:0] prefixes,
  output reg [2:0] prefix_count
);

  integer i, j;
  
  always @* begin
    prefix_count = input_length;
    
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        if (j <= i && i < input_length) begin
          prefixes[i][j] = input_string[j];
        end else begin
          prefixes[i][j] = 8'h00;
        end
      end
    end
  end

endmodule