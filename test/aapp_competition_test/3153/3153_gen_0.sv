module purchase_outcome_decoder(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0][15:0] child_count,
  input  [2:0] purchase_count,
  input  [5:0][1:0][1:0] purchase_pairs,
  output reg [5:0][1:0] outcome,
  output reg done
);

  // Internal registers
  reg [15:0] assigned [3:0];
  reg [2:0]  idx;
  reg [2:0]  remaining;
  reg        busy;

  // Convenient wires for current purchase
  wire [1:0] a_id = purchase_pairs[idx][0];
  wire [1:0] b_id = purchase_pairs[idx][1];

  // Required remaining for selected children
  reg [15:0] required_a;
  reg [15:0] required_b;

  // Outcome for current purchase
  reg [1:0]  outcome_sel;

  // Combinational decision logic for current purchase
  always @* begin
    required_a = child_count[a_id] - assigned[a_id];
    required_b = child_count[b_id] - assigned[b_id];

    // Default
    outcome_sel = 2'd1;

    if ((required_a > required_b) || ((required_a == required_b) && (a_id < b_id))) begin
      outcome_sel = 2'd2; // favor a
    end else if (required_b > required_a) begin
      outcome_sel = 2'd0; // favor b
    end else begin
      outcome_sel = 2'd1; // tie/else
    end
  end

  // Sequential control and state updates
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      for (i = 0; i < 4; i = i + 1) begin
        assigned[i] <= 16'd0;
      end
      for (i = 0; i < 6; i = i + 1) begin
        outcome[i] <= 2'd0;
      end
      idx       <= 3'd0;
      remaining <= 3'd0;
      busy      <= 1'b0;
      done      <= 1'b0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        // Start a new computation
        for (i = 0; i < 4; i = i + 1) begin
          assigned[i] <= 16'd0;
        end
        for (i = 0; i < 6; i = i + 1) begin
          outcome[i] <= 2'd0;
        end
        idx       <= 3'd0;
        remaining <= purchase_count;
        busy      <= 1'b1;
      end else if (busy) begin
        if (remaining != 3'd0) begin
          // Process current purchase
          outcome[idx] <= outcome_sel;

          // Update assigned counts based on outcome
          case (outcome_sel)
            2'd2: begin
              // assign to a
              assigned[a_id] <= assigned[a_id] + 16'd1;
            end
            2'd0: begin
              // assign to b
              assigned[b_id] <= assigned[b_id] + 16'd1;
            end
            default: begin
              // outcome 1: tie/else - no assignment change
            end
          endcase

          // Advance to next purchase
          idx       <= idx + 3'd1;
          remaining <= remaining - 3'd1;

          // When this was the last purchase, next cycle will assert done
          if (remaining == 3'd1) begin
            // All purchases processed now; computation completes next cycle
            // Keep busy high for this cycle; clear next
          end
        end else begin
          // One extra cycle after last purchase: assert done and exit busy
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule