module slime_merger(
    input clk,                  // clock
    input rst_n,                // active-low reset
    input [2:0] n,              // number of slimes (1-8)
    input start,                // pulse high to begin processing
    output reg [2:0] elem_0,    // stack element 0 (leftmost)
    output reg [2:0] elem_1,    // stack element 1
    output reg [2:0] elem_2,    // stack element 2
    output reg [2:0] elem_3,    // stack element 3
    output reg done             // high when computation complete
);

  // Internal parameters and type
  localparam MAX_N = 8;
  localparam STACK_SIZE = 8;
  typedef logic [2:0] value_t;
  typedef value_t stack_t [STACK_SIZE];

  // State machine states
  typedef enum logic [1:0] {IDLE=2'b00, RUN=2'b01, DONE=2'b10} state_t;

  // Internal state
  state_t state;
  logic [3:0] cnt;        // counts how many slimes have been added (0..n)
  logic [3:0] n_lcl;      // latched n (clamped 0..8)
  stack_t stack;
  logic [3:0] sp;         // stack pointer (points to next free slot)

  // Helper function to clamp n to [0,8]
  function [3:0] clamp_n;
    input [2:0] in_n;
    begin
      clamp_n = (in_n > 3'd8) ? 4'd8 : in_n;
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt   <= 4'd0;
      n_lcl <= 4'd0;
      sp    <= 4'd0;
      done  <= 1'b0;
      // Clear internal stack and outputs
      for (int i = 0; i < STACK_SIZE; i++) stack[i] <= 3'd0;
      elem_0 <= 3'd0; elem_1 <= 3'd0; elem_2 <= 3'd0; elem_3 <= 3'd0;
    end else begin
      unique case (state)
        IDLE: begin
          done <= 1'b0;
          cnt  <= 4'd0;
          sp   <= 4'd0;
          for (int i = 0; i < STACK_SIZE; i++) stack[i] <= 3'd0;
          if (start) begin
            n_lcl  <= clamp_n(n);
            // Initialize with first slime (value 1)
            stack[0] <= 3'd1;
            sp       <= 4'd1;
            // Start counting from 0; we have added 1 slime so cnt=0 (processed 0 more)
            state   <= (clamp_n(n) == 4'd0) ? DONE : RUN;
          end
        end

        RUN: begin
          // Are we done processing all slimes?
          if (cnt == (n_lcl - 4'd1)) begin
            // Final cycle: output the top-4 stack elements then assert done
            elem_0 <= (sp > 4'd0) ? stack[0] : 3'd0;
            elem_1 <= (sp > 4'd1) ? stack[1] : 3'd0;
            elem_2 <= (sp > 4'd2) ? stack[2] : 3'd0;
            elem_3 <= (sp > 4'd3) ? stack[3] : 3'd0;
            done   <= 1'b1;
            state  <= IDLE;
          end else begin
            // Normal processing cycle (n_lcl > 0 and not the last iteration)
            if (sp < STACK_SIZE) begin
              stack[sp] <= 3'd1;        // add new slime value 1 to the end
              sp <= sp + 1;
            end
            cnt <= cnt + 1;

            // Merge last two while equal
            // Perform merges at the top of the stack (including the newly added 1)
            if (sp >= 1) begin
              if (sp == 1) begin
                // Only one element: just increment it to 2
                stack[0] <= stack[0] + 1;
              end else begin
                // At least two elements exist: compare the top two
                if (stack[sp-1] == stack[sp-2]) begin
                  // They are equal: merge them into the second last and pop the last
                  stack[sp-2] <= stack[sp-2] + 1;
                  sp <= sp - 1;
                end
              end
            end
          end
        end

        DONE: begin
          // Stay done for exactly one cycle (already outputting in the prior cycle)
          done  <= 1'b0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule
