module cube_elements (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [19:0] nums,
  output logic [59:0] cubes,
  output logic        done
);

  // Internal wires for signed elements
  logic signed [4:0]  elem0, elem1, elem2, elem3;
  logic signed [14:0] cube0, cube1, cube2, cube3;

  // Extract elements (combinational)
  assign elem0 = nums[4:0];
  assign elem1 = nums[9:5];
  assign elem2 = nums[14:10];
  assign elem3 = nums[19:15];

  // Compute cubes combinationally using signed arithmetic
  assign cube0 = elem0 * elem0 * elem0;
  assign cube1 = elem1 * elem1 * elem1;
  assign cube2 = elem2 * elem2 * elem2;
  assign cube3 = elem3 * elem3 * elem3;

  // Register outputs; clear on reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cubes <= 60'd0;
      done  <= 1'b0;
    end else begin
      cubes <= {cube3, cube2, cube1, cube0};
      done  <= 1'b1;
    end
  end

endmodule