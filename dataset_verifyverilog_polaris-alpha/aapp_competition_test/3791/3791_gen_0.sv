module permutation_shift_deviation(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][3:0] p,
  output reg [7:0] min_dev,
  output reg [3:0] shift_id,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_INIT   = 2'b01,
    S_ITER   = 2'b10,
    S_DONE   = 2'b11
  } state_t;

  state_t state, next_state;

  // Registers
  reg [3:0]  cur_shift;          // current shift index (0..15)
  reg [3:0]  i_idx;              // index i (0..15)
  reg [7:0]  cur_dev;            // current deviation accumulator
  reg        busy;               // internal busy flag

  // Combinational signals
  reg [3:0] idx_mod;             // (i + cur_shift) mod n
  reg [4:0] pos_val;             // (i + 1)
  reg [4:0] p_val_ext;           // extended p value
  reg [5:0] diff;                // abs difference up to 15
  reg [7:0] next_dev;            // next deviation value
  reg [7:0] next_min_dev;
  reg [3:0] next_best_shift;

  // Index modulo n (n in [2..16])
  always @* begin
    if (i_idx + cur_shift >= n)
      idx_mod = i_idx + cur_shift - n;
    else
      idx_mod = i_idx + cur_shift;
  end

  // Absolute difference computation
  always @* begin
    pos_val    = i_idx + 5'd1;          // i+1 in range 1..16
    p_val_ext  = {1'b0, p[idx_mod]};    // 0..15
    if (p_val_ext >= pos_val)
      diff = p_val_ext - pos_val;
    else
      diff = pos_val - p_val_ext;
  end

  // Deviation accumulation
  always @* begin
    next_dev = cur_dev + diff;          // max 240 fits in 8 bits
  end

  // Min tracking (for completed shift)
  always @* begin
    next_min_dev    = min_dev;
    next_best_shift = shift_id;
    if (cur_dev < min_dev) begin
      next_min_dev    = cur_dev;
      next_best_shift = cur_shift;
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      // INIT: start calculation for shift 0
      S_INIT: begin
        // After first n cycles of accumulation, move to ITER
        if (i_idx == (n - 1))
          next_state = S_ITER;
      end

      // ITER: process remaining shifts 1..n-1
      S_ITER: begin
        // When we've just finished last element for last shift
        if ((cur_shift == (n - 1)) && (i_idx == (n - 1)))
          next_state = S_DONE;
      end

      S_DONE: begin
        // Wait for start deassertion then reassertion (through IDLE)
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      cur_shift   <= 4'd0;
      i_idx       <= 4'd0;
      cur_dev     <= 8'd0;
      min_dev     <= 8'hFF; // large initial value
      shift_id    <= 4'd0;
      done        <= 1'b0;
      busy        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done      <= 1'b0;
          busy      <= 1'b0;
          min_dev   <= 8'hFF;
          shift_id  <= 4'd0;
          cur_shift <= 4'd0;
          i_idx     <= 4'd0;
          cur_dev   <= 8'd0;
          if (start) begin
            busy    <= 1'b1;
          end
        end

        // INIT: compute deviation for shift 0
        S_INIT: begin
          if (busy) begin
            // Accumulate for current i_idx
            cur_dev <= next_dev;
            // Advance i index
            if (i_idx == (n - 1)) begin
              // Completed shift 0; update min and shift
              if (cur_dev < min_dev) begin
                min_dev  <= cur_dev;
                shift_id <= 4'd0;
              end
              // Prepare for next shift in ITER
              cur_shift <= 4'd1;
              i_idx     <= 4'd0;
              cur_dev   <= 8'd0;
            end else begin
              i_idx <= i_idx + 4'd1;
            end
          end
        end

        // ITER: compute deviations for shifts 1..n-1
        S_ITER: begin
          if (busy) begin
            // Accumulate for current i_idx
            cur_dev <= next_dev;
            if (i_idx == (n - 1)) begin
              // Completed current shift; update global minimum
              min_dev  <= next_min_dev;
              shift_id <= next_best_shift;

              if (cur_shift == (n - 1)) begin
                // All shifts done; transition to DONE next
                // Hold indices; done asserted in S_DONE
              end else begin
                // Move to next shift
                cur_shift <= cur_shift + 4'd1;
                i_idx     <= 4'd0;
                cur_dev   <= 8'd0;
              end
            end else begin
              // Continue within this shift
              i_idx <= i_idx + 4'd1;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
          // Wait in DONE until start is deasserted; state machine
          // will move to IDLE via next_state logic.
        end

        default: begin
          // Safety defaults
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
