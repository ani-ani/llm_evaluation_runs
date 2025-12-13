module sds_finder(
  input clk,
  input rst_n,
  input start,
  input [6:0] r,
  input [7:0] m,
  output reg [4:0] n,
  output reg done
);

  // Internal registers
  reg [7:0] A_current;
  reg [7:0] A_next;
  reg [4:0] current_step;
  reg [255:0] used_values;
  reg [255:0] used_diffs;

  // For per-cycle operations
  reg [3:0] st;                 // internal state
  reg [7:0] d;                  // candidate difference
  reg [7:0] val_iter;           // iterator for existing values
  reg [7:0] diff_val;           // computed diff index
  reg       found_d;            // flag if suitable d found

  // State encoding
  localparam ST_IDLE       = 4'd0;
  localparam ST_INIT       = 4'd1;
  localparam ST_CHECK_M    = 4'd2;
  localparam ST_FIND_D     = 4'd3;
  localparam ST_APPLY_NEXT = 4'd4;
  localparam ST_UPDATE_D   = 4'd5;
  localparam ST_CHECK_DONE = 4'd6;
  localparam ST_FINISH     = 4'd7;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      A_current   <= 8'd0;
      A_next      <= 8'd0;
      current_step<= 5'd0;
      used_values <= 256'd0;
      used_diffs  <= 256'd0;
      n           <= 5'd0;
      done        <= 1'b0;
      st          <= ST_IDLE;
      d           <= 8'd1;
      val_iter    <= 8'd0;
      diff_val    <= 8'd0;
      found_d     <= 1'b0;
    end else begin
      case (st)
        // Wait for start
        ST_IDLE: begin
          done <= 1'b0;
          if (start) begin
            st <= ST_INIT;
          end
        end

        // Initialize state when start asserted
        ST_INIT: begin
          // Initial A1 = r, step=1
          A_current    <= {1'b0, r};
          used_values  <= 256'd0;
          used_diffs   <= 256'd0;
          used_values[{1'b0, r}] <= 1'b1;  // mark A1 used
          current_step <= 5'd1;
          n            <= 5'd0;
          done         <= 1'b0;
          st           <= ST_CHECK_M;
        end

        // Check if m already present (in used_values or used_diffs)
        ST_CHECK_M: begin
          if ( (used_values[m] == 1'b1) || (used_diffs[m] == 1'b1) ) begin
            n    <= current_step;
            done <= 1'b1;
            st   <= ST_FINISH;
          end else begin
            // If exceeded max steps, saturate
            if (current_step > 5'd16) begin
              n    <= 5'd16;
              done <= 1'b1;
              st   <= ST_FINISH;
            end else begin
              // Need to find smallest d > 0 not used as value or diff
              d       <= 8'd1;
              found_d <= 1'b0;
              st      <= ST_FIND_D;
            end
          end
        end

        // Find minimal d > 0 with used_values[d]==0 and used_diffs[d]==0
        ST_FIND_D: begin
          if (!found_d) begin
            if (d > 8'd255) begin
              // Should not occur logically; fall back to saturation
              n    <= 5'd16;
              done <= 1'b1;
              st   <= ST_FINISH;
            end else if ((used_values[d] == 1'b0) && (used_diffs[d] == 1'b0)) begin
              found_d <= 1'b1;
              A_next  <= A_current + d;
              st      <= ST_APPLY_NEXT;
            end else begin
              d <= d + 8'd1;
            end
          end else begin
            st <= ST_APPLY_NEXT;
          end
        end

        // Apply A_next: mark as used value
        ST_APPLY_NEXT: begin
          used_values[A_next] <= 1'b1;
          // Prepare to update diffs vs all used values
          val_iter <= 8'd0;
          st       <= ST_UPDATE_D;
        end

        // Compute and register all new differences |A_next - existing_values|
        ST_UPDATE_D: begin
          if (val_iter < 8'd256) begin
            if (used_values[val_iter]) begin
              if (A_next >= val_iter)
                diff_val <= A_next - val_iter;
              else
                diff_val <= val_iter - A_next;
              used_diffs[diff_val] <= 1'b1;
            end
            val_iter <= val_iter + 8'd1;
          end else begin
            // Finished updating diffs for this step
            A_current <= A_next;
            current_step <= current_step + 5'd1;
            st <= ST_CHECK_M;
          end
        end

        // Not used; retained for clarity/extension
        ST_CHECK_DONE: begin
          st <= ST_CHECK_M;
        end

        // Hold done/n until next start
        ST_FINISH: begin
          if (!start) begin
            st <= ST_IDLE;
          end
        end

        default: begin
          st <= ST_IDLE;
        end
      endcase
    end
  end

endmodule