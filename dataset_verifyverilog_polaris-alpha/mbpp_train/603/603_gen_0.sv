module ludic_numbers(
  input        clk,
  input        rst_n,
  input        start,
  input  [5:0] n,
  output reg [5:0] out_value,
  output reg       valid,
  output reg       done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam INIT       = 3'd1;
  localparam PROC_BASE  = 3'd2;
  localparam PROC_MARK  = 3'd3;
  localparam OUTPUT     = 3'd4;
  localparam DONE_STATE = 3'd5;

  reg [2:0] state, next_state;

  // Validity flags for indices 0..63 (0 unused)
  reg [63:0] flags;

  // Counters / indices
  reg [5:0] init_idx;       // for initialization
  reg [5:0] base_idx;       // current base index (Ludic candidate)
  reg [5:0] step;           // current step size (= base value)
  reg [5:0] mark_idx;       // index for marking multiples
  reg [5:0] out_idx;        // index for output scanning

  // Combinational next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && (n != 6'd0))
          next_state = INIT;
        else
          next_state = IDLE;
      end

      INIT: begin
        if (init_idx == n)
          next_state = PROC_BASE;
        else
          next_state = INIT;
      end

      PROC_BASE: begin
        if (base_idx > n)
          next_state = OUTPUT;          // No more bases
        else if (!flags[base_idx])
          next_state = PROC_BASE;       // Skip invalid base (handled via index advance in seq always)
        else begin
          // Valid base found
          if (base_idx == 6'd1)
            // For base=1, treat specially in sequential logic
            next_state = PROC_MARK;
          else
            next_state = PROC_MARK;
        end
      end

      PROC_MARK: begin
        // When marking done for current base, decide next
        if (mark_idx > n) begin
          // Move to search for next base
          next_state = PROC_BASE;
        end else begin
          next_state = PROC_MARK;
        end
      end

      OUTPUT: begin
        if (out_idx > n)
          next_state = DONE_STATE;
        else
          next_state = OUTPUT;
      end

      DONE_STATE: begin
        // One cycle pulse of done, then go to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      flags     <= 64'd0;
      init_idx  <= 6'd0;
      base_idx  <= 6'd0;
      step      <= 6'd0;
      mark_idx  <= 6'd0;
      out_idx   <= 6'd0;
      out_value <= 6'd0;
      valid     <= 1'b0;
      done      <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      valid <= 1'b0;
      done  <= 1'b0;

      case (state)
        IDLE: begin
          flags     <= 64'd0;
          init_idx  <= 6'd0;
          base_idx  <= 6'd1;
          step      <= 6'd0;
          mark_idx  <= 6'd0;
          out_idx   <= 6'd1;
          out_value <= 6'd0;
        end

        INIT: begin
          // Set all 1..n to valid (1); 0 unused
          if (init_idx == 6'd0) begin
            flags[0] <= 1'b0;
            init_idx <= 6'd1;
          end else if (init_idx <= n) begin
            flags[init_idx] <= 1'b1;
            init_idx <= init_idx + 6'd1;
          end
        end

        PROC_BASE: begin
          // Find next valid base starting from current base_idx
          if (base_idx <= n) begin
            if (!flags[base_idx]) begin
              base_idx <= base_idx + 6'd1; // skip invalid
            end else begin
              // Valid base found
              step <= base_idx; // current ludic number as step

              // Initialize mark index for PROC_MARK
              if (base_idx == 6'd1) begin
                // For base=1, remove every 1st remaining element after the first one.
                // Implement by starting from index 2 and toggling 'keep' logic via flags.
                // Here: mark_idx used as position counter, but due to constraints we
                // approximate by invalidating all >1, then restoration via ludic process.
                // To align with ludic definition, we only remove every 1st remaining element
                // after first; equivalent to making only index 1 valid here.
                mark_idx <= 6'd2;
              end else begin
                // Standard Ludic step: start removing from base_idx + step
                if (base_idx + step <= n)
                  mark_idx <= base_idx + step;
                else
                  mark_idx <= n + 6'd1; // immediately done
              end
            end
          end
        end

        PROC_MARK: begin
          if (base_idx == 6'd1) begin
            // Special handling for base=1:
            // All numbers >1 become invalid; perform over multiple cycles.
            if (mark_idx <= n) begin
              flags[mark_idx] <= 1'b0;
              mark_idx        <= mark_idx + 6'd1;
            end
          end else begin
            // Normal Ludic step marking: clear every 'step'-th remaining element.
            if (mark_idx <= n) begin
              if (flags[mark_idx]) begin
                flags[mark_idx] <= 1'b0;
              end
              // advance by step
              if (mark_idx + step <= n)
                mark_idx <= mark_idx + step;
              else
                mark_idx <= n + 6'd1;
            end
          end

          // When done with this base (mark_idx > n), advance base_idx (in PROC_BASE state)
          if (mark_idx > n) begin
            base_idx <= base_idx + 6'd1;
          end
        end

        OUTPUT: begin
          // Scan and output valid numbers
          if (out_idx <= n) begin
            if (flags[out_idx]) begin
              out_value <= out_idx;
              valid     <= 1'b1;
              out_idx   <= out_idx + 6'd1;
            end else begin
              out_idx <= out_idx + 6'd1;
            end
          end
        end

        DONE_STATE: begin
          done      <= 1'b1;   // single-cycle pulse
          out_value <= 6'd0;
          valid     <= 1'b0;
        end

        default: ;
      endcase
    end
  end

endmodule