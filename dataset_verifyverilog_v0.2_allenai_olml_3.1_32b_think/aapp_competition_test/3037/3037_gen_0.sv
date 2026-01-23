module turtle_dry_finder (
  input clk,
  input rst_n, // active low
  input start,
  input [15:0] target_pattern,
  input [127:0] commands_packed,
  output reg [5:0] min_time,
  output reg [5:0] max_time,
  output reg valid,
  output reg done
);

localparam IDLE = 3'd0,
        FETCH = 3'd1,
        CALCULATE = 3'd2,
        CHECK = 3'd3,
        NEXT = 3'd4,
        FINISHED = 3'd5;

reg [2:0] state,
reg [31:0] command_index,
reg [2:0] remaining_distance,
reg [1:0] current_X, current_Y,
reg [15:0] current_marking,
reg [5:0] min_time, max_time,
reg [5:0] total_step_count,
reg [1:0] current_direction,
reg valid,
reg done;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    command_index <= 32'd0;
    remaining_distance <= 3'd0;
    current_X <= 2'd0;
    current_Y <= 2'd0;
    current_marking <= 16'd0;
    min_time <= 32;
    max_time <= 0;
    valid <= 1'b0;
    done <= 1'b0;
    current_direction <= 2'd0;
    total_step_count <= 6'd0;
  end else begin
    case (state)
      IDLE: begin
        if (start) state <= FETCH;
      end
      FETCH: begin
        reg [3:0] cmd = commands_packed[4*command_index +3 : 4*command_index];
        reg [1:0] distance_code = cmd[3:2];
        reg [1:0] direction = cmd[1:0];
        reg [2:0] distance = distance_code + 3'd1;
        remaining_distance <= distance;
        current_direction <= direction;
        state <= CALCULATE;
      end
      CALCULATE: begin
        case (current_direction)
          2'd0: current_Y <= current_Y + 1;
          2'd1: current_X <= current_X + 1;
          2'd2: current_Y <= current_Y - 1;
          2'd3: current_X <= current_X - 1;
          default: begin
            current_X <= current_X;
            current_Y <= current_Y;
          end
        endcase
        total_step_count <= total_step_count + 1;
        state <= CHECK;
      end
      CHECK: begin
        reg [15:0] bit_pos = current_Y*4 + current_X;
        current_marking <= current_marking | (1 << bit_pos);
        if (current_marking == target_pattern) begin
          if (min_time > total_step_count) min_time <= total_step_count;
          if (max_time < total_step_count) max_time <= total_step_count;
          valid <= 1'b1;
        end
        remaining_distance <= remaining_distance - 1;
        if (remaining_distance > 0) state <= CALCULATE;
        else state <= NEXT;
      end
      NEXT: begin
        command_index <= command_index + 1;
        if (command_index < 32) state <= FETCH;
        else state <= FINISHED;
      end
      FINISHED: begin
      end
    endcase
    done <= (state == FINISHED);
  end
endmodule