module right_insertion #(parameter N=8) (
  input [3:0] value,
  input [N-1:0][3:0] array,
  output reg [3:0] pos
);

  always_comb begin
    logic found;
    found = 0;
    pos = N;
    if (value <= array[0]) begin
      pos = 0;
    end else begin
      for (int i = N-1; i >= 1; i--) begin
        if (!found && (array[i] >= value)) begin
          pos = i;
          found = 1;
        end
      end
    end
  end
endmodule