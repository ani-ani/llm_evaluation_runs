module string_puzzle_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] s1,
  input [7:0][7:0] s2,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [15:0] result_next;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
          end
        end
        COMPUTE: begin
          state <= DONE;
          result <= result_next;
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

  // Combinational logic for computation
  always @(*) begin
    result_next = 16'b0;
    for (int i = 0; i < 8; i++) begin
      // Calculate difference (s2[i] - s1[i])
      int diff = s2[i] - s1[i];
      
      // Normalize to range [-12, 13] using modulo 26
      if (diff > 13) begin
        diff = diff - 26;
      end else if (diff < -12) begin
        diff = diff + 26;
      end
      
      // Take absolute value and add to result
      result_next = result_next + (diff < 0 ? -diff : diff);
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      done <= (state == DONE);
    end
  end

endmodule