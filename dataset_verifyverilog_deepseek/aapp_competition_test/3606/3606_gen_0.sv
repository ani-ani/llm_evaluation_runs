module frog_jump(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] K,
  input [127:0] plant_x,
  input [127:0] plant_y,
  input [31:0] directions,
  output reg [15:0] final_x,
  output reg [15:0] final_y,
  output reg done
);

  reg [15:0] plant_x_reg [0:7];
  reg [15:0] plant_y_reg [0:7];
  reg [7:0] valid_reg;
  reg [3:0] current_index_reg;
  reg [15:0] current_x_reg;
  reg [15:0] current_y_reg;
  reg [3:0] jump_counter_reg;
  reg done_reg;

  wire [1:0] current_direction = (directions >> (30 - (2 * jump_counter_reg))) & 2'b11;

  function automatic logic direction_condition_met (input int j);
    case (current_direction)
      2'b00: return (plant_x_reg[j] < current_x_reg) && (plant_y_reg[j] == current_y_reg);
      2'b01: return (plant_y_reg[j] > current_y_reg) && (plant_x_reg[j] == current_x_reg);
      2'b10: return (plant_x_reg[j] > current_x_reg) && (plant_y_reg[j] == current_y_reg);
      2'b11: return (plant_y_reg[j] < current_y_reg) && (plant_x_reg[j] == current_x_reg);
      default: return 1'b0;
    endcase
  endfunction

  logic found;
  logic [3:0] next_index;
  always_comb begin
    found = 1'b0;
    next_index = current_index_reg;
    for (int j=0; j<8; j++) begin
      if (valid_reg[j] && (j != current_index_reg) && direction_condition_met(j)) begin
        if (!found || (j < next_index)) begin
          found = 1'b1;
          next_index = j;
        end
      end
    end
  end

  wire [3:0] next_jump_counter = jump_counter_reg + 1;
  wire last_jump = (next_jump_counter == K);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<8; i++) begin
        plant_x_reg[i] <= 16'b0;
        plant_y_reg[i] <= 16'b0;
      end
      valid_reg <= 8'b0;
      current_index_reg <= 0;
      current_x_reg <= 16'b0;
      current_y_reg <= 16'b0;
      jump_counter_reg <= 0;
      done_reg <= 1'b0;
      final_x <= 16'b0;
      final_y <= 16'b0;
      done <= 1'b0;
    end else begin
      final_x <= current_x_reg;
      final_y <= current_y_reg;
      done <= done_reg;
      if (start) begin
        for (int i=0; i<8; i++) begin
          plant_x_reg[i] <= plant_x[(i*16)+:16];
          plant_y_reg[i] <= plant_y[(i*16)+:16];
        end
        valid_reg <= (8'd1 << N) - 1;
        current_index_reg <= 0;
        current_x_reg <= plant_x[15:0];
        current_y_reg <= plant_y[15:0];
        jump_counter_reg <= 0;
        done_reg <= 1'b0;
      end else if (!done_reg) begin
        if (jump_counter_reg < K) begin
          jump_counter_reg <= next_jump_counter;
          if (last_jump) done_reg <= 1'b1;
          if (found) begin
            valid_reg[current_index_reg] <= 1'b0;
            current_index_reg <= next_index;
            current_x_reg <= plant_x_reg[next_index];
            current_y_reg <= plant_y_reg[next_index];
          end
        end
      end
    end
  end

endmodule