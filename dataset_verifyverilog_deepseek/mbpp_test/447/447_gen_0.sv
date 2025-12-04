module cube_elements (
  input clk,
  input rst_n,
  input [19:0] nums,
  output reg [59:0] cubes,
  output reg done
);

  logic signed [4:0] elem0, elem1, elem2, elem3;
  logic signed [14:0] cube0_comb, cube1_comb, cube2_comb, cube3_comb;

  assign elem0 = nums[4:0];
  assign elem1 = nums[9:5];
  assign elem2 = nums[14:10];
  assign elem3 = nums[19:15];

  assign cube0_comb = elem0 * elem0 * elem0;
  assign cube1_comb = elem1 * elem1 * elem1;
  assign cube2_comb = elem2 * elem2 * elem2;
  assign cube3_comb = elem3 * elem3 * elem3;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cubes <= 60'b0;
      done <= 1'b0;
    end else begin
      cubes <= {cube3_comb, cube2_comb, cube1_comb, cube0_comb};
      done <= 1'b1;
    end
  end

endmodule