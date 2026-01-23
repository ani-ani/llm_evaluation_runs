module plant_flowers (
  input [7:0] day,
  input [7:0] new_L,
  input [7:0] new_R,
  input [7:0] prev_L [0:7],
  input [7:0] prev_R [0:7],
  input [7:0] prev_H [0:7],
  output [7:0] flowers
);

  reg [3:0] flower_count = 0;
  integer j;

  always @* begin
    flower_count = 0;
    for (j = 0; j < 8; j = j + 1) begin
      if (prev_H[j] != 0 && prev_H[j] < day) begin
        if ((prev_L[j] < new_L && new_L < prev_R[j]) || 
            (prev_L[j] < new_R && new_R < prev_R[j])) begin
          flower_count = flower_count + 1;
        end
      end
    end
  end

  assign flowers = flower_count;

endmodule