module meow_factor (
  input clk, // clock signal
  input rst_n, // active-low synchronous reset
  input start, // pulse high to start computation
  input [39:0] str_in, // 8-character string (each character 5 bits), MSB first
  output reg [3:0] min_ops, // minimal operations required (0-15)
  output reg done // high when computation complete
);

  // Internal signals
  reg [1:0] state, state_next;
  reg [3:0] pos;       // 0..7 position for meow alignment (cost: 8*6 cycles = 16)
  reg [3:0] best;      // running minimum operations found
  reg [3:0] pre_cost;  // deletions before alignment position
  reg [3:0] post_cost; // deletions after the last aligned char
  reg [3:0] subst_cost; // mismatches in the 4-char meow window
  reg [3:0] swap_c;    // at most 1 swap in the 6-char window

  // Extract input characters (5-bit each), MSB first
  wire [4:0] c0, c1, c2, c3, c4, c5, c6, c7;
  assign c0 = str_in[39:35];
  assign c1 = str_in[34:30];
  assign c2 = str_in[29:25];
  assign c3 = str_in[24:20];
  assign c4 = str_in[19:15];
  assign c5 = str_in[14:10];
  assign c6 = str_in[ 9: 5];
  assign c7 = str_in[ 4: 0];

  // Constants for target substring "meow"
  localparam [4:0] CM = 5'd13; // 'm' (5-bit ASCII subset for this task)
  localparam [4:0] CE = 5'd101; // 'e'
  localparam [5:0] CO = 5'd111; // 'o'
  localparam [5:0] CW = 5'd119; // 'w'

  // State machine
  localparam IDLE     = 2'd0;
  localparam CALC     = 2'd1;
  localparam DONE     = 2'd2;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      min_ops <= 4'd0;
    end else begin
      state <= state_next;
    end
  end

  always @(*) begin
    // default
    state_next = state;
    done = 1'b0;
    pos = 4'd0;
    best = 4'd0;
    pre_cost = 4'd0;
    post_cost = 4'd0;
    subst_cost = 4'd0;
    swap_c = 4'd0;
    min_ops = 4'd0;

    case (state)
      IDLE: begin
        if (start) begin
          // start the computation in the next cycle
          state_next = CALC;
        end
      end

      CALC: begin
        // Compute cost for aligning "meow" at position pos (0..7).
        // The 6-char window considered is [pos, pos+5] if pos<=2, or [pos-2, pos+3] if pos>=3.
        // Cost model:
        //   - deletions (pre + post)
        //   - replacements inside the 4-char core (pos..pos+3)
        //   - at most one adjacent swap inside the 6-char window (cost 1 if needed)

        if (pos <= 4'd2) begin
          // 6-char window starts at pos, ends at pos+5
          pre_cost  = pos;                        // chars before window
          post_cost = 4'd2 - pos;                 // chars after pos+5 (total 8 - (pos+6))
          // mismatches over 4 core chars: pos, pos+1, pos+2, pos+3
          subst_cost = (c0 != CM);
          if (pos == 0) begin
            // core: 0,1,2,3
            subst_cost = (c0 != CM) + (c1 != CE) + (c2 != CO) + (c3 != CW);
          end else if (pos == 1) begin
            // core: 1,2,3,4
            subst_cost = (c1 != CM) + (c2 != CE) + (c3 != CO) + (c4 != CW);
          end else begin // pos == 2
            // core: 2,3,4,5
            subst_cost = (c2 != CM) + (c3 != CE) + (c4 != CO) + (c5 != CW);
          end
          // Consider at most one adjacent swap in the 6-char window
          // Check for the needed swap to align the core as "meow"
          // We need: c[pos]=m, c[pos+1]=e, c[pos+2]=o, c[pos+3]=w
          // Swaps are considered only in positions 0..4 inside the window.
          // Conditions derived from matching: swap adds 1 to cost, only if not already equal.
          swap_c = 4'd0;
          if (pos == 0) begin
            // Need c0='m',c1='e',c2='o',c3='w'
            // If these don't hold, try up to one beneficial swap
            // Swaps to try: (0,1), (1,2), (2,3), (3,4), (4,5)
            if ((c0 != CM) || (c1 != CE) || (c2 != CO) || (c3 != CW)) begin
              if ((c1 == CM) && (c0 == CE) && (c2 == CO) && (c3 == CW) && (c4 != CM) && (c5 != CE)) swap_c = 4'd1;
              else if ((c0 == CE) && (c1 == CM) && (c2 == CO) && (c3 == CW) && (c4 != CO) && (c5 != CW)) swap_c = 4'd1;
              else if ((c0 == CM) && (c2 == CE) && (c1 == CO) && (c3 == CW) && (c4 != CW) && (c5 != CM)) swap_c = 4'd1;
              else if ((c0 == CM) && (c1 == CO) && (c2 == CE) && (c3 == CW) && (c4 != CW) && (c5 != CO)) swap_c = 4'd1;
              else if ((c0 == CM) && (c1 == CE) && (c3 == CO) && (c2 == CW) && (c4 != CO) && (c5 != CW)) swap_c = 4'd1;
            end
          end else if (pos == 1) begin
            // Core: 1='m',2='e',3='o',4='w'
            if ((c1 != CM) || (c2 != CE) || (c3 != CO) || (c4 != CW)) begin
              if ((c2 == CM) && (c1 == CE) && (c3 == CO) && (c4 == CW) && (c5 != CM) && (c6 != CE)) swap_c = 4'd1;
              else if ((c1 == CE) && (c2 == CM) && (c3 == CO) && (c4 == CW) && (c5 != CO) && (c6 != CW)) swap_c = 4'd1;
              else if ((c1 == CM) && (c3 == CE) && (c2 == CO) && (c4 == CW) && (c5 != CW) && (c6 != CM)) swap_c = 4'd1;
              else if ((c1 == CM) && (c2 == CO) && (c3 == CE) && (c4 == CW) && (c5 != CW) && (c6 != CO)) swap_c = 4'd1;
              else if ((c1 == CM) && (c2 == CE) && (c4 == CO) && (c3 == CW) && (c5 != CO) && (c6 != CW)) swap_c = 4'd1;
            end
          end else begin // pos == 2
            // Core: 2='m',3='e',4='o',5='w'
            if ((c2 != CM) || (c3 != CE) || (c4 != CO) || (c5 != CW)) begin
              if ((c3 == CM) && (c2 == CE) && (c4 == CO) && (c5 == CW) && (c6 != CM) && (c7 != CE)) swap_c = 4'd1;
              else if ((c2 == CE) && (c3 == CM) && (c4 == CO) && (c5 == CW) && (c6 != CO) && (c7 != CW)) swap_c = 4'd1;
              else if ((c2 == CM) && (c4 == CE) && (c3 == CO) && (c5 == CW) && (c6 != CW) && (c7 != CM)) swap_c = 4'd1;
              else if ((c2 == CM) && (c3 == CO) && (c4 == CE) && (c5 == CW) && (c6 != CW) && (c7 != CO)) swap_c = 4'd1;
              else if ((c2 == CM) && (c3 == CE) && (c5 == CO) && (c4 == CW) && (c6 != CO) && (c7 != CW)) swap_c = 4'd1;
            end
          end
        end else begin
          // pos in [3..7]
          // 6-char window ends at pos, starts at pos-2
          pre_cost  = pos - 4'd2;          // chars before start of window
          post_cost = 4'd7 - pos;          // chars after end of window
          // core: pos, pos+1, pos+2, pos+3
          // compute mismatches for the 4-char core
          // expand a few common cases for 1-cycle combinatorial load
          if (pos == 3) begin
            subst_cost = (c3 != CM) + (c4 != CE) + (c5 != CO) + (c6 != CW);
          end else if (pos == 4) begin
            subst_cost = (c4 != CM) + (c5 != CE) + (c6 != CO) + (c7 != CW);
          end else if (pos == 5) begin
            // core spills beyond S: treat out-of-bounds as mismatches (will be corrected by post deletions)
            subst_cost = (c5 != CM) + (c6 != CE) + (c7 != CO) + (1'b1);
          end else if (pos == 6) begin
            subst_cost = (c6 != CM) + (c7 != CE) + (1'b1) + (1'b1);
          end else begin // pos == 7
            subst_cost = (c7 != CM) + (1'b1) + (1'b1) + (1'b1);
          end
          // At most one adjacent swap in the 6-char window [pos-2..pos+3] (clipped to 0..7)
          // Build 6-char window indices
          swap_c = 4'd0;
          // We'll test up to 5 candidate swaps within the 6-char window
          // Represent window as: w0=start, w5=end; core = w2..w5 (need m,e,o,w)
          if (pos == 3) begin
            // window: [1,2,3,4,5,6]; core: 3,4,5,6
            if ((c3 != CM) || (c4 != CE) || (c5 != CO) || (c6 != CW)) begin
              // candidate swaps within window: (1,2),(2,3),(3,4),(4,5),(5,6)
              if ((c2 == CM) && (c1 == CE) && (c3 == CO) && (c4 == CW) && (c5 != CM) && (c6 != CE)) swap_c = 4'd1;
              else if ((c1 == CM) && (c2 == CE) && (c3 == CO) && (c4 == CW) && (c5 != CO) && (c6 != CW)) swap_c = 4'd1;
              else if ((c1 == CE) && (c2 == CM) && (c3 == CO) && (c4 == CW) && (c5 != CO) && (c6 != CW)) swap_c = 4'd1;
              else if ((c1 == CM) && (c2 == CO) && (c3 == CE) && (c4 == CW) && (c5 != CW) && (c6 != CM)) swap_c = 4'd1;
              else if ((c1 == CM) && (c2 == CE) && (c4 == CO) && (c3 == CW) && (c5 != CO) && (c6 != CW)) swap_c = 4'd1;
            end
          end else if (pos == 4) begin
            // window: [2,3,4,5,6,7]; core: 4,5,6,7
            if ((c4 != CM) || (c5 != CE) || (c6 != CO) || (c7 != CW)) begin
              // swaps: (2,3),(3,4),(4,5),(5,6),(6,7)
              if ((c3 == CM) && (c2 == CE) && (c4 == CO) && (c5 == CW) && (c6 != CM) && (c7 != CE)) swap_c = 4'd1;
              else if ((c2 == CM) && (c3 == CE) && (c4 == CO) && (c5 == CW) && (c6 != CO) && (c7 != CW)) swap_c = 4'd1;
              else if ((c2 == CE) && (c3 == CM) && (c4 == CO) && (c5 == CW) && (c6 != CO) && (c7 != CW)) swap_c = 4'd1;
              else if ((c2 == CM) && (c3 == CO) && (c4 == CE) && (c5 == CW) && (c6 != CW) && (c7 != CM)) swap_c = 4'd1;
              else if ((c2 == CM) && (c3 == CE) && (c5 == CO) && (c4 == CW) && (c6 != CO) && (c7 != CW)) swap_c = 4'd1;
            end
          end else if (pos == 5) begin
            // window: [3,4,5,6,7,?] -> clip to [3,4,5,6,7]; core: 5,6,7,? (last is out-of-bounds)
            // Since we already accounted for out-of-bounds as mismatches via subst_cost,
            // we still allow at most one swap in [3..7] to help align if possible.
            if ((c5 != CM) || (c6 != CE) || (c7 != CO)) begin
              // swaps: (3,4),(4,5),(5,6),(6,7) and (4,5) etc.
              if ((c4 == CM) && (c3 == CE) && (c5 == CO) && (c6 == CW) && (c7 != CM)) swap_c = 4'd1;
              else if ((c3 == CM) && (c4 == CE) && (c5 == CO) && (c6 == CW) && (c7 != CO)) swap_c = 4'd1;
              else if ((c3 == CE) && (c4 == CM) && (c5 == CO) && (c6 == CW) && (c7 != CO)) swap_c = 4'd1;
              else if ((c3 == CM) && (c4 == CO) && (c5 == CE) && (c6 == CW) && (c7 != CW)) swap_c = 4'd1;
              else if ((c3 == CM) && (c4 == CE) && (c6 == CO) && (c5 == CW) && (c7 != CO)) swap_c = 4'd1;
            end
          end else if (pos == 6) begin
            // window: [4,5,6,7]; core: 6,7,?,? (two out-of-bounds)
            if ((c6 != CM) || (c7 != CE)) begin
              // swaps: (4,5),(5,6),(6,7)
              if ((c5 == CM) && (c4 == CE) && (c6 == CO) && (c7 == CW) && (1'b1)) swap_c = 4'd1;
              else if ((c4 == CM) && (c5 == CE) && (c6 == CO) && (c7 == CW) && (1'b1)) swap_c = 4'd1;
              else if ((c4 == CE) && (c5 == CM) && (c6 == CO) && (c7 == CW) && (1'b1)) swap_c = 4'd1;
              else if ((c4 == CM) && (c5 == CO) && (c6 == CE) && (c7 == CW) && (1'b1)) swap_c = 4'd1;
              else if ((c4 == CM) && (c5 == CE) && (c7 == CO) && (c6 == CW) && (1'b1)) swap_c = 4'd1;
            end
          end else begin // pos == 7
            // window: [5,6,7]; core: 7,?,?,? (three out-of-bounds)
            // With most of core out of bounds, swaps can't help; keep swap_c=0
            swap_c = 4'd0;
          end
        end

        best = pre_cost + post_cost + subst_cost + swap_c;

        if (pos == 4'd7) begin
          // Last iteration -> finalize and move to DONE
          state_next = DONE;
          min_ops = best;
        end else begin
          // Next position to evaluate
          state_next = CALC;
        end
      end

      DONE: begin
        // Keep result stable and raise done for one cycle
        state_next = IDLE;
        done = 1'b1;
        min_ops = min_ops; // hold value
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

  // Update position and best on CALC transitions (excluding DONE transition)
  reg [3:0] pos_next;
  always @(posedge clk) begin
    if (!rst_n) begin
      pos <= 4'd0;
    end else begin
      case (state)
        IDLE:  pos <= 4'd0;
        CALC:  begin
          if (state_next == DONE) begin
            // Hold position at 7 (final) for visibility
            pos <= 4'd7;
          end else begin
            pos <= pos + 1'b1;
          end
        end
        DONE:  pos <= 4'd0;
        default: pos <= pos;
      endcase
    end
  end

endmodule
