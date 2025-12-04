module sheldon_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start processing
  input [15:0] num, // input number to check
  output reg done, // high when check complete
  output reg is_sheldon // 1 if number is Sheldon number
);

  // One-hot state encoding
  localparam IDLE         = 6'b000001;
  localparam FIRST_RUN_1  = 6'b000010;
  localparam MEASURE_0    = 6'b000100;
  localparam MEASURE_1    = 6'b001000;
  localparam CHECK        = 6'b010000;
  localparam DONE         = 6'b100000;

  reg [5:0] state, next_state;
  reg [15:0] sr;          // shift register (MSB-first shifting)
  reg [3:0] idx;          // bit index (0..15), 15 means 16 bits remain
  reg [3:0] N;            // length of first run of 1's
  reg [3:0] M;            // length of first run of 0's after the 1's run
  reg [3:0] cnt_cur;      // counter for current run length
  reg [3:0] nextN;        // next N candidate to check against
  reg [3:0] nextM;        // next M candidate to check against
  reg expected;           // expected bit value in current measurement phase
  reg started;            // asserted once first '1' is seen
  reg seen_one;           // indicates at least one '1' was seen (for special case)
  reg valid;              // intermediate validity flag while running

  // State register and outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      is_sheldon <= 1'b0;
    end else begin
      state <= next_state;
      done <= (next_state == DONE);
      is_sheldon <= (next_state == DONE) ? valid : 1'b0;
    end
  end

  // Next-state and datapath logic
  always_comb begin
    // Default maintain current values
    sr        = sr;
    idx       = idx;
    N         = N;
    M         = M;
    cnt_cur   = cnt_cur;
    nextN     = nextN;
    nextM     = nextM;
    expected  = expected;
    started   = started;
    seen_one  = seen_one;
    valid     = valid;
    next_state = state;

    case (state)
      IDLE: begin
        sr        = 16'b0;
        idx       = 4'b0;
        N         = 4'b0;
        M         = 4'b0;
        cnt_cur   = 4'b0;
        nextN     = 4'b0;
        nextM     = 4'b0;
        expected  = 1'b0;
        started   = 1'b0;
        seen_one  = 1'b0;
        valid     = 1'b0;
        if (start) begin
          sr        = num;            // Load input to shift register (MSB at bit 15)
          idx       = 4'd15;          // 16 bits to process
          next_state = FIRST_RUN_1;
        end else begin
          next_state = IDLE;
        end
      end

      FIRST_RUN_1: begin
        // Measure first run of 1's (skip leading zeros)
        expected = 1'b1;
        if (started) begin
          // Already started counting 1's
          if (sr[15] == 1'b1) begin
            cnt_cur = cnt_cur + 1;
            if (idx == 4'b0) begin // last bit processed
              N         = cnt_cur + 1; // include current 1
              valid     = (N > 0);    // at least one 1 must exist
              next_state = DONE;
            end else begin
              sr = {sr[14:0], 1'b0};
              idx = idx - 1;
              next_state = FIRST_RUN_1;
            end
          end else begin
            // First run of 1's ended, now measure zeros
            N           = cnt_cur;   // finalize N
            started     = 1'b0;      // reset for zero measuring
            cnt_cur     = 4'b0;
            next_state  = MEASURE_0;
          end
        end else begin
          // Looking for the first '1' to start counting
          if (sr[15] == 1'b1) begin
            started   = 1'b1;
            seen_one  = 1'b1;
            cnt_cur   = 4'd1;        // count this 1
            if (idx == 4'b0) begin // only one bit (num has a single 1)
              N         = 4'd1;
              valid     = 1'b1;      // single 1 is a special Sheldon number
              next_state = DONE;
            end else begin
              sr = {sr[14:0], 1'b0};
              idx = idx - 1;
              next_state = FIRST_RUN_1;
            end
          end else begin
            // Still skipping leading zeros
            if (idx == 4'b0) begin
              // All zeros: not a Sheldon number (needs at least one '1')
              N         = 4'b0;
              valid     = 1'b0;
              next_state = DONE;
            end else begin
              sr = {sr[14:0], 1'b0};
              idx = idx - 1;
              next_state = FIRST_RUN_1;
            end
          end
        end
      end

      MEASURE_0: begin
        // Measure the first run of 0's that follows the 1's run
        expected = 1'b0;
        if (sr[15] == 1'b0) begin
          cnt_cur = cnt_cur + 1;
          if (idx == 4'b0) begin
            // Number ends with a zero-run; this zero-run must be the M-run
            M         = cnt_cur + 1; // include this zero
            nextN     = N;
            nextM     = M;
            valid     = 1'b1;        // at least have N and M, will be checked in CHECK/DONE
            next_state = CHECK;
          end else begin
            sr = {sr[14:0], 1'b0};
            idx = idx - 1;
            next_state = MEASURE_0;
          end
        end else begin
          // End of zero-run, store M, now expect 1's run
          M         = cnt_cur;
          nextN     = N;
          nextM     = M;
          cnt_cur   = 4'b0;
          next_state = MEASURE_1;
        end
      end

      MEASURE_1: begin
        // Measure subsequent runs of 1's and 0's, checking against N and M
        expected = 1'b1;
        if (sr[15] == 1'b1) begin
          cnt_cur = cnt_cur + 1;
          if (idx == 4'b0) begin
            // Ends on a 1's run; must equal N
            valid = (cnt_cur + 1 == N);
            next_state = DONE;
          end else begin
            sr = {sr[14:0], 1'b0};
            idx = idx - 1;
            next_state = MEASURE_1;
          end
        end else begin
          // End of 1's run; it must equal N
          if (cnt_cur != N) begin
            valid = 1'b0;
            next_state = DONE;
          end else begin
            // Now measure the next 0's run and check against M
            cnt_cur = 4'b0;
            next_state = MEASURE_0;
          end
        end
      end

      CHECK: begin
        // Final validation for special case where input ends after a zero run
        valid = (N > 0) && (M > 0);
        next_state = DONE;
      end

      DONE: begin
        // Hold outputs until start is deasserted; on new start, go to FIRST_RUN_1
        sr        = sr;
        idx       = idx;
        N         = N;
        M         = M;
        cnt_cur   = cnt_cur;
        nextN     = nextN;
        nextM     = nextM;
        expected  = expected;
        started   = started;
        seen_one  = seen_one;
        valid     = valid;
        if (start) begin
          next_state = FIRST_RUN_1;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end
endmodule