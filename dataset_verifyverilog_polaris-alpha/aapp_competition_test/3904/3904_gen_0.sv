module bracket_correction(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start processing
  input [3:0] seq_len, // sequence length (1-16)
  input [15:0] bracket_seq, // packed bracket sequence (1= '(', 0=')')
  output reg [4:0] result, // correction time or -1
  output reg done // high when computation complete
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam CHECK      = 3'd1;
  localparam PROCESS    = 3'd2;
  localparam FINALIZE   = 3'd3;
  localparam OUTPUT     = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [3:0] len_reg;
  reg [4:0] idx; // supports up to 16
  reg signed [5:0] balance; // range [-16,16]
  reg [4:0] total_time; // up to 16
  reg in_negative_seg;

  // Parity / count checking
  reg [4:0] open_count;
  reg [4:0] close_count;
  reg check_done;

  // control
  reg start_d;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      result          <= 5'd0;
      done            <= 1'b0;
      len_reg         <= 4'd0;
      idx             <= 5'd0;
      balance         <= 6'sd0;
      total_time      <= 5'd0;
      in_negative_seg <= 1'b0;
      open_count      <= 5'd0;
      close_count     <= 5'd0;
      check_done      <= 1'b0;
      start_d         <= 1'b0;
    end else begin
      state   <= next_state;
      start_d <= start;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            len_reg         <= seq_len;
            idx             <= 5'd0;
            balance         <= 6'sd0;
            total_time      <= 5'd0;
            in_negative_seg <= 1'b0;
            open_count      <= 5'd0;
            close_count     <= 5'd0;
            check_done      <= 1'b0;
          end
        end

        CHECK: begin
          // One-cycle check: count '(' and ')' using seq_len bits from MSB side
          if (!check_done) begin
            integer i;
            open_count  <= 5'd0;
            close_count <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
              if (i < len_reg) begin
                if (bracket_seq[15 - i])
                  open_count <= open_count + 1'b1;
                else
                  close_count <= close_count + 1'b1;
              end
            end
            check_done <= 1'b1;
          end
        end

        PROCESS: begin
          if (idx < len_reg) begin
            // Extract current bit: use MSB-first for first seq_len bits
            // bit_pos = 15 - idx
            if (bracket_seq[15 - idx])
              balance <= balance + 6'sd1;
            else
              balance <= balance - 6'sd1;

            // Negative segment tracking uses previous cycle's balance.
            // We need combinational look-ahead, so use temporary inside OUTPUT logic.
            // Here we rely on previous balance value; actual segment accounting is done
            // in the next cycle using current balance snapshot.

            idx <= idx + 5'd1;
          end
        end

        FINALIZE: begin
          // Nothing sequential beyond what combinational next_state does
        end

        OUTPUT: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Combinational next state and segment/time logic
  always @* begin
    next_state = state;

    // Default: keep previous result except when explicitly updated
    case (state)
      IDLE: begin
        if (start && !start_d)
          next_state = CHECK;
      end

      CHECK: begin
        if (check_done) begin
          // Validate length even and counts equal
          if ( (len_reg[0] == 1'b1) || (open_count != close_count) ) begin
            // Invalid sequence
            next_state = OUTPUT;
          end else begin
            next_state = PROCESS;
          end
        end
      end

      PROCESS: begin
        // Segment accounting based on the balance evolution.
        // We must use the effective next balance for current character.
        // Derive next_balance combinationally using idx (current index) and bit.
        reg signed [5:0] next_balance;
        reg bit_val;
        bit_val = 1'b0;
        if (idx < len_reg)
          bit_val = bracket_seq[15 - idx];
        // next_balance is what balance will be after current char
        if (idx < len_reg) begin
          if (bit_val)
            next_balance = balance + 6'sd1;
          else
            next_balance = balance - 6'sd1;
        end else begin
          next_balance = balance;
        end

        // Local copies to compute next in_negative_seg/total_time
        reg next_in_neg;
        reg [4:0] next_total_time;
        next_in_neg      = in_negative_seg;
        next_total_time  = total_time;

        if (idx < len_reg) begin
          // entering negative segment
          if (!in_negative_seg && (next_balance < 0)) begin
            next_in_neg     = 1'b1;
            next_total_time = total_time + 5'd1;
          end
          // inside negative segment
          else if (in_negative_seg && (next_balance < 0)) begin
            next_total_time = total_time + 5'd1;
          end
          // exiting negative segment
          else if (in_negative_seg && (next_balance >= 0)) begin
            next_in_neg = 1'b0;
          end
        end

        // Assign back to outputs via blocking (affects only combinationally)
        // Note: since this is combinational, ensure driving dedicated regs via next_state-style.
        // We'll use continuous style by leveraging state persistence next cycle.

        if (idx < len_reg) begin
          next_state = PROCESS;
        end else begin
          next_state = FINALIZE;
        end

        // Because this is combinational, we cannot directly update regs used in seq always.
        // Use implicit latch avoidance by driving them for all paths.
        // Synthesis-wise, we treat them as next values to be captured; but spec restricts us to one always.
        // To keep pure, we won't reassign here; instead, add a separate sequential block for these "next" regs.
      end

      FINALIZE: begin
        // After processing all chars, finalize result.
        // If invalid (from CHECK), we would have gone directly to OUTPUT.
        next_state = OUTPUT;
      end

      OUTPUT: begin
        // Stay one cycle with done=1 and result stable, then go IDLE on next start.
        if (start && !start_d)
          next_state = CHECK;
        else if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Next-value computation for negative segments and total_time
  // Separate always block, driven by state/inputs, captured in main seq block on clk.
  reg [4:0] total_time_next;
  reg in_negative_seg_next;
  reg [4:0] result_next;

  always @* begin
    // Defaults to hold values
    total_time_next      = total_time;
    in_negative_seg_next = in_negative_seg;
    result_next          = result;

    case (state)
      IDLE: begin
        if (start && !start_d) begin
          total_time_next      = 5'd0;
          in_negative_seg_next = 1'b0;
          result_next          = 5'd0;
        end
      end

      CHECK: begin
        if (check_done) begin
          if ( (len_reg[0] == 1'b1) || (open_count != close_count) ) begin
            // invalid sequence -> -1
            result_next = 5'b11111;
          end
        end
      end

      PROCESS: begin
        // Compute next_balance and update negative segment accounting
        reg signed [5:0] next_balance;
        reg bit_val;
        bit_val = 1'b0;
        if (idx < len_reg)
          bit_val = bracket_seq[15 - idx];

        if (idx < len_reg) begin
          if (bit_val)
            next_balance = balance + 6'sd1;
          else
            next_balance = balance - 6'sd1;
        end else begin
          next_balance = balance;
        end

        if (idx < len_reg) begin
          // entering negative seg
          if (!in_negative_seg && (next_balance < 0)) begin
            in_negative_seg_next = 1'b1;
            total_time_next      = total_time + 5'd1;
          end
          // inside negative seg
          else if (in_negative_seg && (next_balance < 0)) begin
            total_time_next      = total_time + 5'd1;
          end
          // exiting negative seg
          else if (in_negative_seg && (next_balance >= 0)) begin
            in_negative_seg_next = 1'b0;
          end
        end
      end

      FINALIZE: begin
        // For valid sequences, latch total_time into result
        if (result != 5'b11111) begin
          result_next = total_time;
        end
      end

      OUTPUT: begin
        // Hold result as is
      end
    endcase
  end

  // Capture next-values for segment and result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_time      <= 5'd0;
      in_negative_seg <= 1'b0;
      result          <= 5'd0;
    end else begin
      total_time      <= total_time_next;
      in_negative_seg <= in_negative_seg_next;
      result          <= result_next;
    end
  end

endmodule