module string_modifier(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [7:0] s1 [0:15], // input string 1 (16 chars max)
  input [7:0] s2 [0:15], // input string 2 (16 chars max)
  input [3:0] length, // actual string length (1-16)
  output reg [8:0] moves, // total moves needed (9-bit)
  output reg done // high when computation completes
);

  // FSM state encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  // FSM and counters
  reg [1:0] state, next_state;
  reg [3:0] i;              // current index (0..15)
  reg [3:0] next_i;
  reg [3:0] remaining;      // characters left to process
  reg [3:0] next_remaining;
  reg [8:0] moves_next;     // next move accumulator
  reg [8:0] run_sum;        // sum of diffs within current directional run
  reg [8:0] run_sum_next;
  reg prev_sign;            // sign of previous diff (0=non-pos, 1=pos)
  reg prev_sign_next;
  reg run_active;           // currently inside a directional run
  reg run_active_next;

  // State register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 4'd0;
      remaining <= 4'd0;
      moves <= 9'd0;
      run_sum <= 9'd0;
      prev_sign <= 1'b0;
      run_active <= 1'b0;
    end else begin
      state <= next_state;
      i <= next_i;
      remaining <= next_remaining;
      moves <= moves_next;
      run_sum <= run_sum_next;
      prev_sign <= prev_sign_next;
      run_active <= run_active_next;
    end
  end

  // Compute next-state and outputs
  always @(*) begin
    // Defaults
    next_state = state;
    next_i = i;
    next_remaining = remaining;
    moves_next = moves;
    run_sum_next = run_sum;
    prev_sign_next = prev_sign;
    run_active_next = run_active;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for processing
          next_state = PROCESSING;
          next_i = 4'd0;
          // Clamp length to 16 and ensure at least 1
          next_remaining = (|length) ? (length > 4'd15 ? 4'd16 : length) : 4'd1;
          moves_next = 9'd0;
          run_sum_next = 9'd0;
          prev_sign_next = 1'b0;
          run_active_next = 1'b0;
        end else begin
          next_state = IDLE;
          next_i = 4'd0;
          next_remaining = 4'd0;
          moves_next = 9'd0;
          run_sum_next = 9'd0;
          prev_sign_next = 1'b0;
          run_active_next = 1'b0;
        end
      end

      PROCESSING: begin
        // Compute minimal circular diff for s1[i] -> s2[i]
        // d in -25..+25, then minimal absolute shift is min(|d|, 26-|d|)
        // Keep the original signed direction for grouping (d)
        wire [8:0] diff_full;
        wire [4:0] diff7; // -25..+25 fits in 6 bits signed; use 5 bits unsigned with sign bit
        wire [5:0] abs_diff6; // 0..25 fits in 6 bits
        reg [8:0] d;
        reg sgn;
        reg [5:0] ad;

        // Compute diff modulo 26 using 7-bit arithmetic to preserve sign correctly
        assign diff_full = $unsigned(s2[i]) - $unsigned(s1[i]);
        // Map 0..127 to -64..+63 effectively; we only care -25..+25 after adjustment
        assign diff7 = diff_full[7:0] - 8'd26; // effective 0..25 - 26 = -26..-1
        // If diff7 is negative, it's in range -25..-1; otherwise 0..25
        assign abs_diff6 = (diff7[5] ? 6'd26 - {1'b0, -diff7[5:0]} : {1'b0, diff7[4:0]});

        always @(*) begin
          d  = {3'b000, diff7};        // sign-extend to 9 bits for clarity
          sgn = d[8] | (d == 9'd0);    // non-positive -> 0, positive -> 1
          ad = abs_diff6;              // 0..25
        end

        if (remaining == 4'd1) begin
          // Last character: finish current run then done
          if (run_active) begin
            // Close the final run
            moves_next = moves + run_sum + ad;
          end else begin
            moves_next = moves + ad;
          end
          next_state = DONE;
          next_i = i;            // unchanged
          next_remaining = 4'd0;
          // reset run state
          run_sum_next = 9'd0;
          prev_sign_next = 1'b0;
          run_active_next = 1'b0;
        end else begin
          // Not the last character
          if (run_active) begin
            if (sgn == prev_sign) begin
              // Continue current run
              run_sum_next = run_sum + ad;
              moves_next = moves;
            end else begin
              // Sign change: close previous run, start new
              moves_next = moves + run_sum;
              run_sum_next = ad;
              prev_sign_next = sgn;
              run_active_next = 1'b1;
            end
          end else begin
            // Start first run
            run_sum_next = ad;
            prev_sign_next = sgn;
            run_active_next = 1'b1;
            moves_next = moves;
          end

          // Advance to next character
          next_i = i + 1;
          next_remaining = remaining - 1;
        end
      end

      DONE: begin
        // Hold results; return to IDLE on deasserted start
        next_i = 4'd0;
        next_remaining = 4'd0;
        moves_next = moves;
        run_sum_next = 9'd0;
        prev_sign_next = 1'b0;
        run_active_next = 1'b0;
        if (start) begin
          next_state = DONE;  // remain done while start is held
        end else begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
        next_i = 4'd0;
        next_remaining = 4'd0;
        moves_next = 9'd0;
        run_sum_next = 9'd0;
        prev_sign_next = 1'b0;
        run_active_next = 1'b0;
      end
    endcase
  end

  // Output done flag
  always @(*) begin
    if (state == IDLE) done = 1'b1;
    else if (state == DONE) done = 1'b1;
    else done = 1'b0;
  end

endmodule
