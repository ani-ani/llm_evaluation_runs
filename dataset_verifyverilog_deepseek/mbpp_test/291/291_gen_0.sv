module fence_painting (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  output reg [15:0] result,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, CALCULATE, DONE} state_t;
  state_t state, next_state;
  
  reg [2:0] counter;
  reg [15:0] current_dp;
  reg [15:0] prev_dp;
  
  wire [15:0] k_16 = {14'b0, k};
  wire [15:0] k_minus_1 = k_16 - 16'd1;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_dp <= 16'd0;
      prev_dp <= 16'd0;
      counter <= 3'd0;
      result <= 16'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= CALCULATE;
            current_dp <= k_16;
            prev_dp <= 16'd0;
            counter <= 3'd1;
            // Immediately finish if n==1
            if (n == 3'd1) begin
              result <= k_16;
              state <= DONE;
              done <= 1'b1;
            end
          end
        end
        
        CALCULATE: begin
          if (counter < n) begin
            counter <= counter + 1;
            if (counter == 3'd1) begin
              current_dp <= k_16 * k_16;
              prev_dp <= current_dp;
            end else begin
              current_dp <= k_minus_1 * (current_dp + prev_dp);
              prev_dp <= current_dp;
            end
          end else begin
            result <= current_dp;
            state <= DONE;
            done <= 1'b1;
          end
        end
        
        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule