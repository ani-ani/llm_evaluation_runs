module divisible_subset(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] numbers [7:0],
  input  [2:0] size,
  output reg [3:0] max_size,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam PROCESS = 2'b01;
  localparam DONE    = 2'b10;

  reg [1:0] state, next_state;

  // Internal registers
  reg [3:0] dp [7:0];        // DP array
  reg [2:0] i_idx;           // Current i index
  reg [2:0] j_idx;           // Current j index (for scanning j > i)
  reg [3:0] max_j_dp;        // Max dp[j] satisfying divisibility for current i
  reg [3:0] global_max;      // Max of all dp[i]
  reg [2:0] last_i;          // size-1
  reg       init_process;    // Flag to initialize PROCESS on start
  reg       scan_done;       // Indicates scanning for current i is done
  reg       all_i_done;      // Indicates all i processed

  // Division remainder wires (for divisibility checks)
  reg [7:0] a_val, b_val;
  reg [7:0] rem_ab, rem_ba;

  // Combinational division remainder for unsigned 8-bit (simple iterative)
  function automatic [7:0] udiv_rem;
    input [7:0] dividend;
    input [7:0] divisor;
    integer k;
    reg [8:0] r;
  begin
    if (divisor == 8'd0) begin
      udiv_rem = dividend; // define as dividend when divisor is 0 (no divide)
    end else begin
      r = 9'd0;
      for (k = 7; k >= 0; k = k - 1) begin
        r = {r[7:0], dividend[k]};
        if (r[8:1] >= divisor)
          r[8:1] = r[8:1] - divisor;
      end
      udiv_rem = r[8:1];
    end
  end
  endfunction

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESS;
      end
      PROCESS: begin
        if (all_i_done) next_state = DONE;
      end
      DONE: begin
        // Stay in DONE until start is deasserted, then go IDLE
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      max_size    <= 4'd0;
      done        <= 1'b0;
      global_max  <= 4'd0;
      i_idx       <= 3'd0;
      j_idx       <= 3'd0;
      max_j_dp    <= 4'd0;
      last_i      <= 3'd0;
      init_process<= 1'b0;
      scan_done   <= 1'b0;
      all_i_done  <= 1'b0;
      dp[0]       <= 4'd0;
      dp[1]       <= 4'd0;
      dp[2]       <= 4'd0;
      dp[3]       <= 4'd0;
      dp[4]       <= 4'd0;
      dp[5]       <= 4'd0;
      dp[6]       <= 4'd0;
      dp[7]       <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          max_size    <= 4'd0;
          global_max  <= 4'd0;
          all_i_done  <= 1'b0;
          scan_done   <= 1'b0;
          init_process<= 1'b0;
          // Clear dp
          dp[0]       <= 4'd0;
          dp[1]       <= 4'd0;
          dp[2]       <= 4'd0;
          dp[3]       <= 4'd0;
          dp[4]       <= 4'd0;
          dp[5]       <= 4'd0;
          dp[6]       <= 4'd0;
          dp[7]       <= 4'd0;

          if (start) begin
            // Initialize indices based on size
            if (size == 3'd0) begin
              last_i <= 3'd0;
              i_idx  <= 3'd0;
            end else begin
              last_i <= size - 3'd1;
              i_idx  <= size - 3'd1;
            end
            j_idx        <= 3'd0; // will be set when PROCESS starts
            max_j_dp     <= 4'd0;
            init_process <= 1'b1;
          end
        end

        PROCESS: begin
          // Initialization when entering PROCESS from IDLE
          if (init_process) begin
            // Base case: for last_i index, dp[last_i] = 1
            dp[last_i]   <= 4'd1;
            global_max   <= 4'd1;
            // Prepare for next i (last_i - 1), if any
            if (last_i == 3'd0) begin
              // Only one element
              i_idx      <= last_i;
              all_i_done <= 1'b1;
            end else begin
              i_idx      <= last_i - 3'd1;
              all_i_done <= 1'b0;
            end
            // For first scalable i iteration, start scanning j = i+1
            j_idx        <= last_i; // placeholder, will be updated below
            max_j_dp     <= 4'd0;
            scan_done    <= 1'b0;
            init_process <= 1'b0;
          end else if (!all_i_done) begin
            // For current i_idx, perform sequential scan over j from i_idx+1 to last_i
            if (!scan_done) begin
              // Setup initial j when starting scan
              if (j_idx <= i_idx || j_idx > last_i) begin
                if (i_idx < last_i)
                  j_idx <= i_idx + 3'd1;
                else
                  scan_done <= 1'b1; // no j to scan if i_idx == last_i
              end else begin
                // Perform divisibility check between numbers[i_idx] and numbers[j_idx]
                a_val = numbers[i_idx];
                b_val = numbers[j_idx];

                // Check a divides b or b divides a (avoid divide by zero)
                if (a_val != 8'd0 && b_val != 8'd0) begin
                  rem_ab = udiv_rem(b_val, a_val);
                  rem_ba = udiv_rem(a_val, b_val);
                  if ((rem_ab == 8'd0) || (rem_ba == 8'd0)) begin
                    // Valid pair, consider dp[j_idx]
                    if (dp[j_idx] > max_j_dp)
                      max_j_dp <= dp[j_idx];
                  end
                end

                // Move to next j or finish scan
                if (j_idx == last_i) begin
                  scan_done <= 1'b1;
                end else begin
                  j_idx <= j_idx + 3'd1;
                end
              end
            end else begin
              // Scan for current i_idx done: compute dp[i_idx]
              dp[i_idx] <= max_j_dp + 4'd1;

              // Update global max
              if (max_j_dp + 4'd1 > global_max)
                global_max <= max_j_dp + 4'd1;

              // Prepare for next i_idx
              if (i_idx == 3'd0) begin
                // All i processed
                all_i_done <= 1'b1;
              end else begin
                i_idx      <= i_idx - 3'd1;
                j_idx      <= 3'd0;     // will be set on next cycle
                max_j_dp   <= 4'd0;
                scan_done  <= 1'b0;
              end
            end
          end
        end

        DONE: begin
          done     <= 1'b1;
          max_size <= global_max;
          // Hold result until start is deasserted and FSM returns to IDLE
        end

        default: begin
          // Should not occur; reset-like behavior
          done       <= 1'b0;
          max_size   <= 4'd0;
          global_max <= 4'd0;
        end
      endcase
    end
  end

endmodule