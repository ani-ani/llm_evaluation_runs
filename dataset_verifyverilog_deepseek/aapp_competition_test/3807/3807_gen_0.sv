module greedy_block_tower(
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  output reg [7:0] block_count,
  output reg [15:0] volume_X,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    FIND_CUBE,
    UPDATE
  } state_t;

  reg [15:0] current_remaining_volume;
  reg [5:0] current_a;
  state_t current_state, next_state;
  reg [15:0] cube_val;
  reg found_valid;
  reg [5:0] found_a;

  always_comb begin
    found_valid = 1'b0;
    found_a = 6'b0;
    for (int i = 40; i >= 1; i--) begin
      cube_val = i * i * i;
      if (cube_val <= current_remaining_volume) begin
        found_a = i;
        found_valid = 1'b1;
        break;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      block_count <= 8'b0;
      volume_X <= 16'b0;
      done <= 1'b0;
      current_remaining_volume <= 16'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_remaining_volume <= m;
            block_count <= 8'b0;
            volume_X <= 16'b0;
            current_state <= FIND_CUBE;
          end
        end

        FIND_CUBE: begin
          if (found_valid) begin
            current_a <= found_a;
            current_state <= UPDATE;
          end else begin
            done <= 1'b1;
            current_state <= IDLE;
          end
        end

        UPDATE: begin
          current_remaining_volume <= current_remaining_volume - (current_a * current_a * current_a);
          volume_X <= volume_X + (current_a * current_a * current_a);
          block_count <= block_count + 1;
          if (block_count == 8'd127) begin
            done <= 1'b1;
            current_state <= IDLE;
          end else begin
            current_state <= FIND_CUBE;
          end
        end
      endcase
    end
  end

endmodule