module frequency_max(
  input clk,
  input rst_n,
  input start,
  input [3:0] data [0:7],
  output reg [4:0] result,
  output reg done
);

  typedef enum {IDLE, COUNT, COMPARE, DONE} state_t;
  state_t current_state, next_state;

  reg [3:0] freq [1:15];  // Frequency counters (ignore index 0)
  reg [3:0] i;            // Loop counter
  reg found_valid;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 5'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          result <= 5'b0;
          done <= 1'b0;
        end

        COUNT: begin
          // Initialize frequencies to 0
          if (next_state == COUNT) begin
            for (i = 1; i <= 15; i = i + 1)
              freq[i] <= 4'b0;
          end
          
          // Count frequencies
          for (i = 0; i < 8; i = i + 1) begin
            if (data[i] != 0)
              freq[data[i]] <= freq[data[i]] + 1;
          end
        end

        COMPARE: begin
          found_valid <= 1'b0;
          result <= 5'b11111;  // Default to -1
          
          // Find max valid value (15 down to 1)
          for (i = 15; i >= 1; i = i - 1) begin
            if ((freq[i] >= i) && !found_valid) begin
              found_valid <= 1'b1;
              result <= {1'b0, i};
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start)
          next_state = COUNT;
      end
      
      COUNT: begin
        next_state = COMPARE;
      end
      
      COMPARE: begin
        next_state = DONE;
      end
      
      DONE: begin
        if (start)
          next_state = COUNT;
      end
    endcase
  end

endmodule