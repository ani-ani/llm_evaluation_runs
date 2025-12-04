module warlord_region_calc(
  input clk,
  input rst_n,
  input start,
  input [2:0] W,
  input [2:0] N_lines,
  input [15:0] lines [0:7][3:0],
  output reg [2:0] k,
  output reg done
);

  reg [1:0] state;
  reg [2:0] cycle_count;
  reg [2:0] stored_count;
  reg signed [16:0] stored_dx [0:7];
  reg signed [16:0] stored_dy [0:7];
  reg signed [16:0] dx, dy;
  reg is_new_direction;

  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      k <= 0;
      cycle_count <= 0;
      stored_count <= 0;
      for (int i = 0; i < 8; i++) begin
        stored_dx[i] <= 0;
        stored_dy[i] <= 0;
      end
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            cycle_count <= 0;
            stored_count <= 0;
            for (int i = 0; i < 8; i++) begin
              stored_dx[i] <= 0;
              stored_dy[i] <= 0;
            end
          end
        end
        PROCESSING: begin
          cycle_count <= cycle_count + 1;

          if (cycle_count < N_lines) begin
            dx = lines[cycle_count][2] - lines[cycle_count][0];
            dy = lines[cycle_count][3] - lines[cycle_count][1];
          end
          else begin
            dx = 0;
            dy = 0;
          end

          is_new_direction = 1;
          for (int j = 0; j < 8; j++) begin
            if (j < stored_count) begin
              if ( (dx * stored_dy[j] - dy * stored_dx[j]) == 0 ) 
                is_new_direction = 0;
            end
          end

          if (cycle_count < N_lines) begin
            if (is_new_direction) begin
              stored_dx[stored_count] <= dx;
              stored_dy[stored_count] <= dy;
              stored_count <= stored_count + 1;
            end
          end

          if (cycle_count == 7) begin
            state <= DONE;
            if ((2 * stored_count) >= W) begin
              k <= 0;
            end
            else begin
              k <= (W - 2 * stored_count + 1) / 2;
            end
            done <= 1'b1;
          end
        end
        DONE: begin
          state <= IDLE;
          done <= 1'b0;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule