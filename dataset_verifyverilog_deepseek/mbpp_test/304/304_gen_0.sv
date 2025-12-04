module rotation_index_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] arr [0:7],
  input [2:0] ranges [0:3][0:1],
  input [1:0] rotations,
  input [2:0] index,
  output reg [3:0] result,
  output reg done
);

  reg [3:0] arr_reg [0:7];
  reg [2:0] ranges_reg [0:3][0:1];
  reg [1:0] rotations_reg;
  reg [2:0] current_index;
  reg [1:0] cycle_counter;
  reg processing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arr_reg <= '{default: '0};
      ranges_reg <= '{default: '{default: '0}};
      rotations_reg <= '0;
      current_index <= '0;
      cycle_counter <= '0;
      processing <= 1'b0;
      result <= '0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      if (start) begin
        arr_reg <= arr;
        ranges_reg <= ranges;
        rotations_reg <= rotations;
        current_index <= index;
        cycle_counter <= '0;
        processing <= 1'b1;
      end else if (processing) begin
        if (cycle_counter < rotations_reg) begin
          automatic logic [1:0] j = rotations_reg - cycle_counter - 1;
          if (current_index >= ranges_reg[j][0] && current_index <= ranges_reg[j][1]) begin
            if (current_index == ranges_reg[j][0]) begin
              current_index <= ranges_reg[j][1];
            end else begin
              current_index <= current_index - 1;
            end
          end
          cycle_counter <= cycle_counter + 1;
        end else begin
          result <= arr_reg[current_index];
          done <= 1'b1;
          processing <= 1'b0;
        end
      end
    end
  end

endmodule