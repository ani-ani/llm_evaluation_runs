module max_removal_score(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] array_in [7:0],
  output reg [18:0] max_score,
  output reg done
);

  // State encoding
  localparam IDLE          = 3'd0;
  localparam INITIALIZE    = 3'd1;
  localparam STACK_PROCESS = 3'd2;
  localparam FINAL_PROCESS = 3'd3;
  localparam DONE_STATE    = 3'd4;

  reg [2:0] state, next_state;

  // Internal storage for input array
  reg [15:0] arr [7:0];

  // Stack implementation
  reg [15:0] stack [7:0];
  reg [3:0]  sp; // stack pointer: number of elements in stack (0..8)

  // Indices and control
  reg [3:0] idx; // current index into arr (0..7)
  reg [18:0] score;

  // Helper wires
  wire [15:0] next_in;
  assign next_in = arr[idx];

  // Min function
  function automatic [15:0] min16;
    input [15:0] a, b;
    begin
      min16 = (a < b) ? a : b;
    end
  endfunction

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      max_score <= 19'd0;
      done      <= 1'b0;
      sp        <= 4'd0;
      idx       <= 4'd0;
      score     <= 19'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          max_score <= max_score; // hold
          if (start) begin
            // Capture input array and init
            arr[0] <= array_in[0];
            arr[1] <= array_in[1];
            arr[2] <= array_in[2];
            arr[3] <= array_in[3];
            arr[4] <= array_in[4];
            arr[5] <= array_in[5];
            arr[6] <= array_in[6];
            arr[7] <= array_in[7];

            score  <= 19'd0;
            sp     <= 4'd0;
            idx    <= 4'd0;
          end
        end

        INITIALIZE: begin
          // Push first element if n>0
          if (sp == 0 && n != 0) begin
            stack[0] <= arr[0];
            sp       <= 4'd1;
            idx      <= 4'd1;
          end
        end

        STACK_PROCESS: begin
          // Two main phases per element:
          // 1) Consume input elements (push + conditional pops).
          // 2) After inputs, clean up remaining stack.

          if (idx < n) begin
            // Process next input element in a single cycle style:
            // Push current element
            stack[sp] <= next_in;
            sp        <= sp + 1'b1;
            idx       <= idx + 1'b1;

            // Conditional removals using current next_in as neighbor
            // Use temporary copies for combinational-style updates
            // but commit sequentially in this cycle.
            // We'll approximate single-step hardware stack behavior:
            // while top <= min(prev, next_in) do pop and add.
            begin : POP_LOOP_INPUT
              integer k;
              reg [3:0] t_sp;
              reg [18:0] t_score;
              reg [15:0] t_next;
              reg [15:0] top;
              reg [15:0] prev;
              reg [15:0] m;

              t_sp    = sp + 1'b1; // after push
              t_score = score;
              t_next  = next_in;

              // Bounded loop (stack depth <=8)
              for (k = 0; k < 8; k = k + 1) begin
                if (t_sp > 1) begin
                  top  = stack[t_sp-1];
                  prev = stack[t_sp-2];
                  m   = min16(prev, t_next);
                  if (top <= m) begin
                    t_score = t_score + m;
                    t_sp    = t_sp - 1'b1; // pop top
                  end else begin
                    // Stop if condition fails
                    k = 8;
                  end
                end else begin
                  k = 8;
                end
              end

              // Commit updated values
              sp    <= t_sp;
              score <= t_score;
            end
          end else begin
            // No more input elements; fall-through to FINAL_PROCESS via state
          end
        end

        FINAL_PROCESS: begin
          // Process remaining stack elements using last element as neighbor
          // For final cleanup, we use neighbor as 0 (or itself) depending
          // on typical max-removal-stack problems. Here we choose:
          // while stack size>1: remove top if top <= prev, add min(prev, top).
          begin : POP_LOOP_FINAL
            integer k2;
            reg [3:0] t_sp2;
            reg [18:0] t_score2;
            reg [15:0] top2;
            reg [15:0] prev2;
            reg [15:0] m2;

            t_sp2    = sp;
            t_score2 = score;

            for (k2 = 0; k2 < 8; k2 = k2 + 1) begin
              if (t_sp2 > 1) begin
                top2  = stack[t_sp2-1];
                prev2 = stack[t_sp2-2];
                m2    = min16(prev2, top2);
                if (top2 <= prev2) begin
                  t_score2 = t_score2 + m2;
                  t_sp2    = t_sp2 - 1'b1;
                end else begin
                  k2 = 8;
                end
              end else begin
                k2 = 8;
              end
            end

            sp    <= t_sp2;
            score <= t_score2;
          end
        end

        DONE_STATE: begin
          done      <= 1'b1;
          max_score <= score;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (n == 0)
            next_state = DONE_STATE;
          else
            next_state = INITIALIZE;
        end
      end

      INITIALIZE: begin
        // After pushing first element, proceed to stack processing
        next_state = STACK_PROCESS;
      end

      STACK_PROCESS: begin
        // When all inputs consumed, move to final processing
        if (idx >= n)
          next_state = FINAL_PROCESS;
        else
          next_state = STACK_PROCESS;
      end

      FINAL_PROCESS: begin
        // Single-cycle bounded cleanup; then go to DONE
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        // Wait for next start; optionally return to IDLE when start deasserted
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule