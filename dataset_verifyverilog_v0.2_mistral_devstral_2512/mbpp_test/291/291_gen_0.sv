module fence_painter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] k,
  output reg [29:0] result,
  output reg done
);

  // Constants
  localparam MOD = 30'h3B9ACA07;
  localparam IDLE = 2'b00;
  localparam CALC_BASE = 2'b01;
  localparam CALC_LOOP = 2'b10;
  localparam DONE = 2'b11;

  // State register
  reg [1:0] state, next_state;

  // Intermediate registers
  reg [29:0] dp_prev2, dp_prev1, dp_current;
  reg [4:0] counter;

  // Modulo operation function
  function [29:0] mod_op;
    input [31:0] val;
    begin
      mod_op = val % MOD;
    end
  endfunction

  // State transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 30'b0;
      counter <= 5'b0;
      dp_prev2 <= 30'b0;
      dp_prev1 <= 30'b0;
      dp_current <= 30'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_BASE;
      end
      CALC_BASE: begin
        if (n == 1 || n == 2) next_state = DONE;
        else next_state = CALC_LOOP;
      end
      CALC_LOOP: begin
        if (counter == n - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Already handled in state transition
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= 30'b0;
        end
        CALC_BASE: begin
          if (n == 1) begin
            result <= k;
            done <= 1'b1;
          end else if (n == 2) begin
            result <= mod_op(k * k);
            done <= 1'b1;
          end else begin
            dp_prev2 <= k;
            dp_prev1 <= mod_op(k * k);
            counter <= 3;
          end
        end
        CALC_LOOP: begin
          if (counter == n) begin
            result <= dp_current;
            done <= 1'b1;
          end else begin
            dp_current <= mod_op((k - 1) * (dp_prev1 + dp_prev2));
            dp_prev2 <= dp_prev1;
            dp_prev1 <= dp_current;
            counter <= counter + 1;
          end
        end
        DONE: begin
          // Hold result
        end
      endcase
    end
  end

endmodule