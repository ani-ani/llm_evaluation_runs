module max_removal_score(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] n,
  input reg [15:0] array_in [7:0],
  output reg [18:0] max_score,
  output reg done
);

  // State encoding
  localparam IDLE = 3'd0;
  localparam INITIALIZE = 3'd1;
  localparam STACK_PROCESS = 3'd2;
  localparam FINAL_PROCESS = 3'd3;
  localparam DONE = 3'd4;

  // Internal signals
  logic [2:0] state;
  logic [15:0] stack_mem [0:8]; // up to 9 stack entries
  logic [3:0] sp;               // stack pointer (next free slot)
  logic [3:0] i;                // index of next array element to push
  logic [15:0] curr;            // current element being processed
  logic [15:0] min_val;         // temporary min value
  logic pop_phase;              // 0 = push phase, 1 = pop phase
  logic [18:0] score;           // accumulated score

  // Sequential logic with active‑low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sp <= 4'b0;
      i <= 4'b0;
      score <= 19'b0;
      pop_phase <= 1'b0;
      done <= 1'b0;
      max_score <= 19'b0;       // clear output for completeness
      // clear stack
      for (int k = 0; k < 9; k++) begin
        stack_mem[k] <= 16'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= INITIALIZE;
          end
        end

        INITIALIZE: begin
          sp <= 4'b0;
          i <= 4'b0;
          score <= 19'b0;
          pop_phase <= 1'b0;
          done <= 1'b0;
          for (int k = 0; k < 9; k++) begin
            stack_mem[k] <= 16'b0;
          end
          state <= STACK_PROCESS;
        end

        STACK_PROCESS: begin
          if (i < n) begin
            if (!pop_phase) begin
              // Push the current array element onto the stack
              stack_mem[sp] <= array_in[i];
              curr <= array_in[i];
              sp <= sp + 1;
              pop_phase <= 1'b1; // switch to pop phase
            end else begin
              // Pop loop: remove while condition holds
              if (sp >= 2) begin
                min_val <= (stack_mem[sp-2] < curr) ? stack_mem[sp-2] : curr;
                if (stack_mem[sp-1] <= min_val) begin
                  // Remove top element
                  sp <= sp - 1;
                  score <= score + min_val;
                  // Remain in pop phase
                end else begin
                  // Condition false, move to next element
                  pop_phase <= 1'b0;
                  i <= i + 1;
                end
              end else begin
                // Not enough elements to compare
                pop_phase <= 1'b0;
                i <= i + 1;
              end
            end
            // stay in STACK_PROCESS for next cycle
          end else begin
            // All inputs processed -> final flush
            state <= FINAL_PROCESS;
          end
        end

        FINAL_PROCESS: begin
          // Sentinel value (largest 16‑bit value)
          if (sp > 1) begin
            // min is the second top element because sentinel is max
            min_val <= stack_mem[sp-2];
            if (stack_mem[sp-1] <= stack_mem[sp-2]) begin
              // Pop top, add second top to score
              sp <= sp - 1;
              score <= score + min_val;
              // continue flushing
            end else begin
              // No more removals possible
              state <= DONE;
            end
          end else begin
            // Stack has 0 or 1 element left
            state <= DONE;
          end
        end

        DONE: begin
          max_score <= score;
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
