module sorted_arrays_median (
  input clk,
  input rst_n,
  input start,
  input [7:0] arr1 [0:7],
  input [7:0] arr2 [0:7],
  input [2:0] n,
  output reg [8:0] med_sum,
  output reg done
);

  // States
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Internal pointers and counters
  reg [2:0] i, next_i;
  reg [2:0] j, next_j;
  reg [3:0] count, next_count; // up to 8 needs 4 bits
  reg [7:0] m1, next_m1;
  reg [7:0] m2, next_m2;

  // Compute median index targets
  logic [2:0] med_idx_low;  // floor(n/2)  -> index of 1st median candidate
  logic [2:0] med_idx_high; // floor(n/2)+1 -> index of 2nd median candidate
  always_comb begin
    // n in [3..7]
    med_idx_low  = {1'b0, n[2:1]};           // floor(n/2)
    med_idx_high = med_idx_low + 1;          // next position
  end

  // Choose current m1/m2 based on progress
  always_comb begin
    if (count <= med_idx_low) begin
      m1 = next_m1; // not reached yet; keep previous (will be updated on next cycle)
      m2 = next_m2;
    end else begin
      m1 = next_m1;
      m2 = next_m2;
    end
  end

  // State and datapath update
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state     <= IDLE;
      i         <= 3'b0;
      j         <= 3'b0;
      count     <= 4'b0;
      m1        <= 8'b0;
      m2        <= 8'b0;
      med_sum   <= 9'b0;
      done      <= 1'b0;
    end else begin
      state     <= next_state;
      i         <= next_i;
      j         <= next_j;
      count     <= next_count;
      m1        <= next_m1;
      m2        <= next_m2;
      med_sum   <= (next_state == DONE) ? ({1'b0, next_m1} + {1'b0, next_m2}) : 9'b0;
      done      <= (next_state == DONE);
    end
  end

  // Next-state logic
  always_comb begin
    // Defaults (avoid latches)
    next_state = state;
    next_i     = i;
    next_j     = j;
    next_count = count;
    next_m1    = m1;
    next_m2    = m2;

    case (state)
      IDLE: begin
        next_i     = 3'b0;
        next_j     = 3'b0;
        next_count = 4'b0;
        next_m1    = 8'b0;
        next_m2    = 8'b0;
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // one comparison and one selection per cycle (n+1 total)
        if (i < n && (j >= n || arr1[i] < arr2[j])) begin
          // take from arr1
          next_m1    = (count == med_idx_low)  ? arr1[i] : m1;
          next_m2    = (count == med_idx_high) ? arr1[i] : m2;
          next_i     = i + 1;
          next_j     = j;
        end else begin
          // take from arr2 (j < n guaranteed here)
          next_m1    = (count == med_idx_low)  ? arr2[j] : m1;
          next_m2    = (count == med_idx_high) ? arr2[j] : m2;
          next_i     = i;
          next_j     = j + 1;
        end
        next_count = count + 1;

        // n+1 comparisons -> then go to DONE (additional cycle to output)
        if (count == n) begin // performed (n+1) comparisons (0..n)
          next_state = DONE;
        end
      end

      DONE: begin
        // Hold outputs until next start or reset
        next_i     = i;
        next_j     = j;
        next_count = count;
        next_m1    = m1;
        next_m2    = m2;
        if (start) begin
          // Re-start on start pulse
          next_state = PROCESSING;
          next_i     = 3'b0;
          next_j     = 3'b0;
          next_count = 4'b0;
          next_m1    = 8'b0;
          next_m2    = 8'b0;
        end else begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
