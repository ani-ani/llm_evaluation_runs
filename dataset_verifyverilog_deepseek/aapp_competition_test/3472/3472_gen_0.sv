module warlord_region_calc (
  input clk,
  input rst_n,
  input start,
  input [2:0] W,
  input [2:0] N_lines,
  input [15:0] lines [0:7][3:0],
  output reg [2:0] k,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state, next_state;
  
  reg [2:0] cnt;
  reg [3:0] D;
  
  typedef struct packed {
    logic signed [16:0] dx;
    logic signed [16:0] dy;
  } dir_t;
  
  dir_t dirs [0:7];
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      k <= 3'b000;
      cnt <= 3'b000;
      D <= 4'b0000;
      for (int i = 0; i < 8; i++) begin
        dirs[i] <= '{dx: 17'b0, dy: 17'b0};
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= PROCESSING;
            cnt <= 3'b000;
            D <= 4'b0000;
          end
        end
        
        PROCESSING: begin
          if (cnt < 3'd7) begin
            cnt <= cnt + 1;
          end else begin
            state <= DONE;
          end
          
          if (cnt < N_lines) begin
            logic signed [16:0] dx, dy;
            logic unique;
            
            dx = signed'(lines[cnt][2]) - signed'(lines[cnt][0]);
            dy = signed'(lines[cnt][3]) - signed'(lines[cnt][1]);
            
            unique = 1'b1;
            for (int j = 0; j < cnt; j++) begin
              if (dx * dirs[j].dy == dy * dirs[j].dx) begin
                unique = 1'b0;
              end
            end
            
            if (unique) begin
              D <= D + 1;
            end
            dirs[cnt] <= '{dx: dx, dy: dy};
          end
        end
        
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
          
          begin
            logic [4:0] R;
            R = 2 * D;
            if (R >= W) begin
              k <= 3'b000;
            end else begin
              k <= (W - R + 1) / 2;
            end
          end
        end
      endcase
    end
  end
endmodule