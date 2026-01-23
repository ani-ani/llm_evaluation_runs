module game_solver (
  input clk,
  input rst_n,
  input [1:0] start_pos,
  input [1:0] target_pos,
  input start,
  output reg [7:0] result,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE
  } state_t;
  state_t state, next_state;

  // Distance buffer (3x3x8)
  reg [7:0] dist_buffer [0:2][0:2];
  reg [7:0] next_dist_buffer [0:2][0:2];

  // Iteration counter
  reg [4:0] iter_cnt;
  reg [4:0] max_iter = 5'd32;

  // Initialize distance buffer
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 8'hFF;
      iter_cnt <= 5'd0;
      for (int i = 0; i < 3; i++) begin
        for (int j = 0; j < 3; j++) begin
          dist_buffer[i][j] <= (i == j) ? 8'd0 : 8'hFF;
        end
      end
    else begin
      state <= next_state;
      if (state == COMPUTE) begin
        // Update distance buffer
        for (int u = 0; u < 3; u++) begin
          for (int T = 0; T < 3; T++) begin
            if (u == T) begin
              next_dist_buffer[u][T] = 8'd0;
            end else begin
              reg [7:0] min_val = 8'hFF;
              // Option 1
              reg [7:0] max_opt1 = 8'd0;
              case (u)
                0: max_opt1 = dist_buffer[1][T]; // a -> b
                1: max_opt1 = dist_buffer[1][T]; // b -> b (opt1)
                2: max_opt1 = (dist_buffer[0][T] > dist_buffer[1][T]) ? dist_buffer[0][T] : dist_buffer[1][T]; // c -> {a,b}
              endcase
              // Option 2
              reg [7:0] max_opt2 = 8'd0;
              case (u)
                0: max_opt2 = 8'hFF; // a has only one option
                1: max_opt2 = dist_buffer[0][T]; // b -> a (opt2)
                2: max_opt2 = (dist_buffer[0][T] > dist_buffer[2][T]) ? dist_buffer[0][T] : dist_buffer[2][T]; // c -> {a,c}
              endcase
              // Compute min of maxes
              if (max_opt1 < min_val) min_val = max_opt1;
              if (max_opt2 < min_val) min_val = max_opt2;
              // Update next distance
              if (min_val != 8'hFF) begin
                next_dist_buffer[u][T] = min_val + 1;
              end else begin
                next_dist_buffer[u][T] = 8'hFF;
              end
            end
          end
        end
        // Copy next buffer to current
        for (int i = 0; i < 3; i++) begin
          for (int j = 0; j < 3; j++) begin
            dist_buffer[i][j] <= next_dist_buffer[i][j];
          end
        end
        // Increment iteration counter
        if (iter_cnt == max_iter - 1) begin
          iter_cnt <= 5'd0;
          next_state = IDLE;
          done <= 1'b1;
          result <= dist_buffer[start_pos][target_pos];
        end else begin
          iter_cnt <= iter_cnt + 1;
        end
      end
    end
  end

  // State transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            next_state = COMPUTE;
            done <= 1'b0;
            iter_cnt <= 5'd0;
          end else begin
            next_state = IDLE;
          end
        end
        COMPUTE: next_state = COMPUTE;
        default: next_state = IDLE;
      endcase
    end
  end

endmodule