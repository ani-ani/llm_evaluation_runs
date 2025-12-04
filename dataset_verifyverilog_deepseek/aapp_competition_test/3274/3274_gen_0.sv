module torpedo_avoidance (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_seconds,
  input [2:0] m_ships,
  input signed [4:0] ship_x1 [0:3],
  input signed [4:0] ship_x2 [0:3],
  input [3:0] ship_y [0:3],
  output reg [1:0] path [0:7],
  output reg done,
  output reg possible
);

  reg [3:0] step_cnt;
  reg [16:0] pos_storage[0:7]; // x: -8(0) ~ +8(16) @ 8 steps
  reg [16:0] move_left[0:7]; // left movement (-1)
  reg [16:0] move_hold[0:7]; // hold movement (0)
  reg [16:0] move_right[0:7]; // right movement (+1)
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      possible <= 0;
      path <= '{default:0};
      pos_storage <= '{default:0};
      move_left <= '{default:0};
      move_hold <= '{default:0};
      move_right <= '{default:0};
      step_cnt <= 0;
    end else begin
      if (start) begin
        if (step_cnt < n_seconds) begin
          // Compute possible positions
          reg [16:0] prev_pos;
          reg [16:0] next_u, next_h, next_d;
          
          if (step_cnt == 0) prev_pos = 17'b00000000100000000; // x=0 @ y=0
          else prev_pos = pos_storage[step_cnt-1];
          
          // Calculate movements (boundary masked)
          next_d = (prev_pos << 1) & 17'h1FFFF; // right (+1)
          next_h = prev_pos; // hold (0)
          next_u = (prev_pos >> 1); // left (-1)
          
          // Collision detection
          reg [16:0] block_mask = 0;
          for (int i=0; i<m_ships; i++) begin
            if (ship_y[i] == (step_cnt + 1)) begin
              int signed min_x = (ship_x1[i] < ship_x2[i]) ? ship_x1[i] : ship_x2[i];
              int signed max_x = (ship_x1[i] > ship_x2[i]) ? ship_x1[i] : ship_x2[i];
              for (int x=min_x; x<=max_x; x++) begin
                block_mask[x+8] = 1'b1;
              end
            end
          end
          
          reg [16:0] next_pos = (next_u | next_h | next_d) & ~block_mask;
          
          // Store results
          pos_storage[step_cnt] <= next_pos;
          move_left[step_cnt] <= next_u;
          move_hold[step_cnt] <= next_h;
          move_right[step_cnt] <= next_d;
          step_cnt <= step_cnt + 1;
          done <= 0;
        end else begin
          // Final step (n_seconds)
          if (pos_storage[n_seconds-1]) possible <= 1;
          else possible <= 0;
          
          // Path extraction (combinational via storage)
          if (pos_storage[n_seconds-1]) begin
            // Find first possible x in last step
            int final_x = 0;
            for (int i=0; i<=16; i++) begin
              if (pos_storage[n_seconds-1][i]) begin
                final_x = i; break;
              end
            end
            
            // Backtrace path
            int current_x = final_x;
            for (int step_idx= n_seconds-1; step_idx >=0; step_idx--) begin
              if (step_idx == 0) begin
                // Initial movement from x=0
                case (current_x)
                  7: path[0] = 2'b00; // -1
                  8: path[0] = 2'b01; // 0
                  9: path[0] = 2'b10; // +1
                  default: path[0] = 0;
                endcase
              end else begin
                if (current_x < 16 && move_right[step_idx][current_x] && pos_storage[step_idx-1][current_x-1]) begin
                  path[step_idx] = 2'b10; // +1
                  current_x = current_x - 1;
                end else if (move_hold[step_idx][current_x] && pos_storage[step_idx-1][current_x]) begin
                  path[step_idx] = 2'b01; // 0
                end else if (current_x > 0 && move_left[step_idx][current_x] && pos_storage[step_idx-1][current_x+1]) begin
                  path[step_idx] = 2'b00; // -1
                  current_x = current_x + 1;
                end
              end
            end
          end
          
          done <= 1;
          step_cnt <= 0;
        end
      end else begin
        done <= 0;
      end
    end
  end
endmodule