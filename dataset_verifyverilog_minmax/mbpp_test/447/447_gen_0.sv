module cube_elements (
  input clk,
  input rst_n,
  input reg [19:0] nums,
  output reg [59:0] cubes,
  output reg done
);

logic [4:0] elem0, elem1, elem2, elem3;
logic signed [14:0] cube0, cube1, cube2, cube3;
logic [59:0] cubes_comb;

always @(*) begin
  elem0 = nums[4:0];
  elem1 = nums[9:5];
  elem2 = nums[14:10];
  elem3 = nums[19:15];
  cube0 = $signed(elem0) * $signed(elem0) * $signed(elem0);
  cube1 = $signed(elem1) * $signed(elem1) * $signed(elem1);
  cube2 = $signed(elem2) * $signed(elem2) * $signed(elem2);
  cube3 = $signed(elem3) * $signed(elem3) * $signed(elem3);
end

assign cubes_comb = { cube3, cube2, cube1, cube0 };

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cubes <= 60'd0;
    done <= 1'b0;
  end
  else begin
    cubes <= cubes_comb;
    done <= 1'b1;
  end
end

endmodule