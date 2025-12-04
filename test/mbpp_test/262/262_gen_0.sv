module array_splitter(
  input  [63:0] flat_array,
  input  [2:0]  L,
  output [63:0] part1,
  output [63:0] part2
);

  reg [63:0] part1_r;
  reg [63:0] part2_r;

  always @(*) begin
    case (L)
      3'd0: begin
        part1_r = 64'h0;
        part2_r = flat_array;
      end
      3'd1: begin
        part1_r = {56'h0, flat_array[7:0]};
        part2_r = {flat_array[63:8], 8'h0};
      end
      3'd2: begin
        part1_r = {48'h0, flat_array[15:0]};
        part2_r = {flat_array[63:16], 16'h0};
      end
      3'd3: begin
        part1_r = {40'h0, flat_array[23:0]};
        part2_r = {flat_array[63:24], 24'h0};
      end
      3'd4: begin
        part1_r = {32'h0, flat_array[31:0]};
        part2_r = {flat_array[63:32], 32'h0};
      end
      3'd5: begin
        part1_r = {24'h0, flat_array[39:0]};
        part2_r = {flat_array[63:40], 40'h0};
      end
      3'd6: begin
        part1_r = {16'h0, flat_array[47:0]};
        part2_r = {flat_array[63:48], 48'h0};
      end
      3'd7: begin
        part1_r = {8'h0, flat_array[55:0]};
        part2_r = {flat_array[63:56], 56'h0};
      end
      default: begin
        part1_r = 64'h0;
        part2_r = 64'h0;
      end
    endcase
  end

  assign part1 = part1_r;
  assign part2 = part2_r;

endmodule