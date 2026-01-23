module max_sum_dp (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [15:0] dp [0:16];
  reg [3:0] current_index;

  // State transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end
        INIT: begin
          state <= PROCESSING;
          current_index <= 2;
        end
        PROCESSING: begin
          if (current_index == n) begin
            state <= DONE;
          end else begin
            current_index <= current_index + 1;
          end
        end
        DONE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end
      endcase
    end
  end

  // LUT initialization and processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dp[0] <= 0;
      dp[1] <= 1;
      for (int i = 2; i <= 16; i++) begin
        dp[i] <= 0;
      end
    end else begin
      case (state)
        INIT: begin
          dp[0] <= 0;
          dp[1] <= 1;
          for (int i = 2; i <= 16; i++) begin
            dp[i] <= 0;
          end
        end
        PROCESSING: begin
          if (current_index > 1) begin
            reg [15:0] sum_part;
            reg [15:0] max_val;
            
            // Calculate sum_part = dp[i/2] + dp[i/3] + dp[i/4] + dp[i/5]
            sum_part = dp[current_index >> 1] + 
                       dp[current_index / 3] + 
                       dp[current_index >> 2] + 
                       dp[current_index / 5];
            
            // Calculate max(i, sum_part)
            max_val = (current_index > sum_part) ? current_index : sum_part;
            
            dp[current_index] <= max_val;
          end
        end
      endcase
    end
  end

  // Output assignment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (state == DONE) begin
        result <= dp[n];
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

endmodule