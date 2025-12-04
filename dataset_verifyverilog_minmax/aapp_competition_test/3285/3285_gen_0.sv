module sds_finder(
  input clk,                   // clock signal
  input rst_n,                 // active-low reset
  input start,                 // start computation (pulse high)
  input [6:0] r,               // initial value A1 (1-100)
  input [7:0] m,               // target value (1-255)
  output reg [4:0] n,          // result step (1-16)
  output reg done              // high when computation completes
);

  // Internal state
  reg [7:0] A_current;         // Current A value
  reg [7:0] A_next;            // Next A value
  reg [4:0] current_step;      // 1..16
  reg [4:0] next_step;         // next value of current_step

  // 256-bit bitsets (bit i -> value i)
  reg [255:0] used_values;
  reg [255:0] used_diffs;
  reg [255:0] next_used_values;
  reg [255:0] next_used_diffs;

  // Bits set for new differences computed at this step
  reg [255:0] new_diff_bits;
  reg [255:0] next_new_diff_bits;

  // FSM state
  localparam IDLE = 1'b0;
  localparam RUN  = 1'b1;
  reg state, next_state;
  reg diffs_were_updated;
  reg next_diffs_were_updated;

  integer i;

  // Next-state logic (combinational)
  always_comb begin
    // Defaults
    next_state          = state;
    next_step           = current_step;
    A_next              = A_current;
    next_used_values    = used_values;
    next_used_diffs     = used_diffs;
    next_new_diff_bits  = 1'b0;
    n                   = 5'd0; // Will be overridden when done is set
    done                = 1'b0;
    next_diffs_were_updated = diffs_were_updated;

    if (state == IDLE) begin
      if (start) begin
        // Initialize for a new run
        next_state = RUN;
        next_step  = 5'd1;
        // Initialize A_current = r, used_values = {r}, used_diffs = 0
        A_next              = r[7:0];
        next_used_values    = (256'b1 << r[7:0]);
        next_used_diffs     = 256'b0;
        next_new_diff_bits  = 256'b0;
        next_diffs_were_updated = 1'b0;
        // Detect immediately if m is found at step 1 (i.e., if m == r)
        if ((m[7:0] == r[7:0]) || (used_diffs[m[7:0]])) begin
          n    = 5'd1;
          done = 1'b1;
          next_state = IDLE; // Complete in 1 cycle
        end else begin
          n    = 5'd0;
          done = 1'b0;
        end
      end else begin
        // Remain idle
        next_state = IDLE;
        next_step  = current_step;
        A_next     = A_current;
        next_used_values    = used_values;
        next_used_diffs     = used_diffs;
        next_new_diff_bits  = new_diff_bits;
        next_diffs_were_updated = diffs_were_updated;
        n    = 5'd0;
        done = 1'b0;
      end
    end else begin // RUN
      // If m was found in a previous step, hold done until idle
      if (done) begin
        n           = n;
        next_state  = IDLE;
        next_step   = current_step;
        A_next      = A_current;
        next_used_values  = used_values;
        next_used_diffs   = used_diffs;
        next_new_diff_bits  = new_diff_bits;
        next_diffs_were_updated = diffs_were_updated;
      end else begin
        // At the beginning of the cycle, check if m is already in sets (including new diffs from previous step)
        if (used_values[m[7:0]] || used_diffs[m[7:0]] || new_diff_bits[m[7:0]]) begin
          n           = current_step;
          done        = 1'b1;
          next_state  = IDLE;      // Exit after this cycle
          next_step   = current_step;
          A_next      = A_current;
          next_used_values  = used_values;
          next_used_diffs   = used_diffs;
          next_new_diff_bits  = new_diff_bits;
          next_diffs_were_updated = diffs_were_updated;
        end else if (current_step > 5'd16) begin
          // Saturation: no find within 16 steps
          n           = 5'd16;
          done        = 1'b1;
          next_state  = IDLE;
          next_step   = 5'd16;
          A_next      = A_current;
          next_used_values  = used_values;
          next_used_diffs   = used_diffs;
          next_new_diff_bits  = new_diff_bits;
          next_diffs_were_updated = diffs_were_updated;
        end else begin
          // Compute next A (SDS rule): choose smallest d>0 not in used_values or used_diffs
          // then A_next = A_current + d (with wrap at 256)
          reg [7:0] d;
          reg found;
          d = 8'd0;
          found = 1'b0;
          for (i = 1; i < 256; i = i + 1) begin
            if (!found) begin
              if (!used_values[i] && !used_diffs[i]) begin
                d = i[7:0];
                found = 1'b1;
              end
            end
          end
          // If not found, wrap-around should not happen due to available candidates, but default d=0 for completeness
          A_next = (A_current + d);

          // Update used_values: set bit for A_next
          next_used_values = used_values | (256'b1 << A_next);

          // Compute new differences |A_next - v| for all existing v in used_values (includes r and previous A's)
          // For this step, the set of existing values is current 'used_values' (A_next not yet included)
          reg [255:0] diff_bits;
          diff_bits = 256'b0;
          for (i = 0; i < 256; i = i + 1) begin
            if (used_values[i]) begin
              if (A_next >= i) diff_bits[A_next - i] = 1'b1;
              else diff_bits[i - A_next] = 1'b1;
            end
          end
          next_new_diff_bits = diff_bits;
          next_used_diffs = used_diffs | diff_bits;

          // Prepare next step
          next_step = current_step + 1;
          n         = 5'd0;
          done      = 1'b0;
          next_state = RUN;
          next_diffs_were_updated = 1'b1;
        end
      end
    end
  end

  // Sequential logic (clocked)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state               <= IDLE;
      current_step        <= 5'd0;
      A_current           <= 8'd0;
      used_values         <= 256'b0;
      used_diffs          <= 256'b0;
      new_diff_bits       <= 256'b0;
      diffs_were_updated  <= 1'b0;
      n                   <= 5'd0;
      done                <= 1'b0;
    end else begin
      // State and controls
      state               <= next_state;
      current_step        <= next_step;
      A_current           <= A_next;
      used_values         <= next_used_values;
      used_diffs          <= next_used_diffs;
      new_diff_bits       <= next_new_diff_bits;
      diffs_were_updated  <= next_diffs_were_updated;
      n                   <= n;  // n is updated when done=1
      done                <= done;
    end
  end

endmodule
