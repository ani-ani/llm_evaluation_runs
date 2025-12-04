module max_array_sum (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_mode,
  input [15:0] data [14:0],
  output reg [15:0] max_sum,
  output reg done
);

  // Pipeline gating: process only the first (2*n_mode-1) elements
  wire gate;                 // 1 during accumulation, 0 otherwise
  reg [19:0] gate_sr;        // Shift register tracking gate high phase (20 stages)

  // Accumulation and decision logic
  reg [31:0] sum_abs;        // Sum of absolute values (needs up to 15*32767 ≈ 491k)
  reg [3:0] neg_count;       // Count of negative elements
  reg [15:0] min_abs;        // Minimum absolute value seen
  reg [15:0] min_abs_reg;    // Pipeline for min_abs across result stage

  // FSM state (20-cycle pipeline: 15 ACCUM + 3 RESULT + 2 DONE)
  reg [4:0] state;
  localparam IDLE    = 5'd0;
  localparam ACCUM   = 5'd1;  // runs for 15 cycles
  localparam RESULT0 = 5'd16; // cycle 16: compute result candidate
  localparam RESULT1 = 5'd17; // cycle 17: choose min_abs
  localparam RESULT2 = 5'd18; // cycle 18: final result stable
  localparam DONE    = 5'd19; // cycles 19+: hold result

  // Gate shift-register (20 stages). Gate=1 only during ACCUM.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gate_sr <= 20'd0;
    end else begin
      gate_sr <= {gate_sr[18:0], gate};
    end
  end
  assign gate = gate_sr[19]; // 1 during the first 15 cycles of the 20-stage pipeline

  // FSM state advance
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE:    state <= start ? ACCUM : IDLE;
        ACCUM:   state <= (state == 5'd15) ? RESULT0 : (state + 1);
        RESULT0: state <= RESULT1;
        RESULT1: state <= RESULT2;
        RESULT2: state <= DONE;
        DONE:    state <= start ? ACCUM : DONE; // allow restart anytime in DONE
        default: state <= IDLE;
      endcase
    end
  end

  // Combinational data path
  wire [15:0] cur;            // current element being processed (valid when gate=1)
  wire cur_abs;               // absolute value of current element
  wire cur_neg;               // sign of current element

  // 20-stage shift register for input array (MSB is the newest element)
  reg [15:0] d_in_reg [14:0]; // reversed indexing: [0]=oldest, [14]=newest
  integer i;
  always @(posedge clk) begin
    d_in_reg[0]  <= data[14];
    d_in_reg[1]  <= data[13];
    d_in_reg[2]  <= data[12];
    d_in_reg[3]  <= data[11];
    d_in_reg[4]  <= data[10];
    d_in_reg[5]  <= data[9];
    d_in_reg[6]  <= data[8];
    d_in_reg[7]  <= data[7];
    d_in_reg[8]  <= data[6];
    d_in_reg[9]  <= data[5];
    d_in_reg[10] <= data[4];
    d_in_reg[11] <= data[3];
    d_in_reg[12] <= data[2];
    d_in_reg[13] <= data[1];
    d_in_reg[14] <= data[0];
  end

  // The most significant register holds the newest element in the gate window
  assign cur = d_in_reg[14];
  assign cur_neg = cur[15];
  assign cur_abs = cur_neg ? (~cur + 1) : cur; // abs = (~x + 1) if x<0 else x

  // Sequential updates for accumulation and result logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_abs    <= 32'd0;
      neg_count  <= 4'd0;
      min_abs    <= 16'h7FFF; // largest 16-bit positive value
      min_abs_reg <= 16'h7FFF;
      max_sum    <= 16'd0;
      done       <= 1'b0;
    end else begin
      // Default: hold outputs; we'll update based on state and gate
      done       <= 1'b0; // will be overridden when reaching RESULT2/DONE

      case (state)
        IDLE: begin
          sum_abs   <= 32'd0;
          neg_count <= 4'd0;
          min_abs   <= 16'h7FFF;
          min_abs_reg <= 16'h7FFF;
          max_sum   <= 16'd0;
          done      <= 1'b0;
        end

        ACCUM: begin
          // Accumulate only if gate==1 (i.e., within the first 2*n-1 elements)
          if (gate) begin
            sum_abs   <= sum_abs + cur_abs;
            neg_count <= neg_count + (cur_neg ? 1'b1 : 1'b0);
            min_abs   <= (cur_abs < min_abs) ? cur_abs : min_abs;
          end
          // Hold previous values of outputs during ACCUM
          min_abs_reg <= min_abs_reg; // keep previous
          max_sum     <= max_sum;     // keep previous
          done        <= 1'b0;
        end

        RESULT0: begin
          // Compute tentative result and capture current min_abs
          min_abs_reg <= min_abs;
          // parity check: odd n (n_mode[0]) or even number of negatives (no borrow)
          if (n_mode[0] || ~neg_count[0]) begin
            max_sum <= sum_abs[15:0]; // sum_abs fits in lower 16 bits by design
          end else begin
            max_sum <= (sum_abs - (min_abs << 1))[15:0];
          end
          done <= 1'b0;
        end

        RESULT1, DONE: begin
          // Keep min_abs stable and final result valid
          min_abs_reg <= min_abs_reg;
          max_sum     <= max_sum; // already finalized in RESULT0
          done        <= 1'b1;    // result is valid starting from RESULT2 and beyond
        end

        default: begin
          sum_abs    <= sum_abs;
          neg_count  <= neg_count;
          min_abs    <= min_abs;
          min_abs_reg<= min_abs_reg;
          max_sum    <= max_sum;
          done       <= done;
        end
      endcase
    end
  end

endmodule
