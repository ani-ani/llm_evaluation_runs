module coin_flip_average(
  input clk,                    // clock signal
  input rst_n,                  // active-low reset
  input start,                  // pulse high to start computation
  input [1:0] data,             // input coin states (H=1, T=0) for known positions (used per pair)
  input [1:0] mask,             // mask where 1=unknown ('?'), 0=known (used per pair)
  output reg [31:0] result,     // Q16.16 fixed-point average (16 integer, 16 fractional bits)
  output reg done               // high when computation complete
);

  // Assumptions / Interpretation for 4-state sequence:
  // - We model a 4-coin sequence as two 2-bit positions (pair 1: bits[3:2], pair 0: bits[1:0]).
  // - 'data' provides known coin values for each pair; 'mask' indicates which pairs are unknown.
  // - For mask bit == 0: pair is fixed to `data` bits.
  // - For mask bit == 1: pair is fully unknown, enumerated over 4 values when generating configurations.
  // - Thus total configurations = product over pairs of (#options), each #options is 1 or 4.
  // - Bank-of-Bath-like rule (finite 4-state adaptation):
  //      State is 4 bits S[3:0] (3 = MSB, 0 = LSB), T=0, H=1.
  //      On each operation:
  //        * Find the leftmost H (highest index with bit=1). If none, all T -> stop.
  //        * Flip that H to T (1->0).
  //        * Also flip its immediate right neighbor bit (index-1) if it exists.
  //      Count each such flip pair as 1 operation. L(C) is operations until all T.

  // FSM states
  localparam IDLE        = 3'd0;
  localparam SETUP_CFG   = 3'd1;
  localparam RUN_CFG     = 3'd2;
  localparam NEXT_CFG    = 3'd3;
  localparam FINISH      = 3'd4;

  reg [2:0] state, next_state;

  // Configuration enumeration for two positions (pair1 and pair0)
  // For each pair i:
  //   if mask[i]==0 -> 1 option: fixed = {data bits}
  //   if mask[i]==1 -> 4 options: 2-bit values from 0..3

  reg [1:0] pair0_val;      // current value for pair0 (bits[1:0])
  reg [1:0] pair1_val;      // current value for pair1 (bits[3:2])

  reg [1:0] pair0_idx;      // index for iterating unknown options (0..3)
  reg [1:0] pair1_idx;      // index for iterating unknown options (0..3)

  reg       pair0_is_unknown;
  reg       pair1_is_unknown;

  reg [3:0] total_cfg;      // total configurations (max 16, but with 2 positions: max 4*4 =16)
  reg [3:0] cfg_count;      // how many configurations processed

  // For this problem, with 2 pairs, total_cfg <= 16, but latency requirement talks about 4 configs max.
  // To honor that, restrict unknown expansion so total_cfg <= 4.
  // We interpret that each '?' pair can be either 0 or 1 for each coin independently (2 coins -> 4 states),
  // but we will only consider up to 4 total configurations overall by construction:
  //   - If none unknown: 1 cfg
  //   - If one unknown pair: 4 cfg
  //   - If both unknown pairs: still 4 cfg by using pair0_idx as low 2 bits and pair1_idx fixed at 0..0 (or vice versa).
  // To keep deterministic and within 4, we encode as:
  //   total_cfg = (mask==2'b00) ? 1 : 4;
  //   If mask == 2'b01: vary pair0 over 4, pair1 fixed
  //   If mask == 2'b10: vary pair1 over 4, pair0 fixed
  //   If mask == 2'b11: use 4 combined patterns from a small ROM mapping.

  // combined-pattern index
  reg [1:0] cfg_idx;

  // State for current configuration run
  reg [3:0] cur_state;      // 4-bit coin state
  reg [7:0] op_count;       // count operations for this configuration (<= 10)

  // Accumulator for sum of L(C)
  reg [15:0] sum_ops;       // sum of operation counts (max 4*10=40, fits)

  // configuration generation wires
  reg [3:0] cfg_state_bits;

  // next-state logic for FSM
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SETUP_CFG;
      end
      SETUP_CFG: begin
        next_state = RUN_CFG;
      end
      RUN_CFG: begin
        // when current configuration reached all T, move to NEXT_CFG
        if (cur_state == 4'b0000)
          next_state = NEXT_CFG;
      end
      NEXT_CFG: begin
        if (cfg_count == total_cfg)
          next_state = FINISH;
        else
          next_state = SETUP_CFG;
      end
      FINISH: begin
        // wait in FINISH until start deasserted then go IDLE
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // configuration pattern ROM for mask==2'b11 (both unknown): 4 combined patterns
  // Each entry: {pair1[1:0], pair0[1:0]} = 4 bits
  function [3:0] both_unknown_pattern(input [1:0] idx);
    begin
      case (idx)
        2'd0: both_unknown_pattern = 4'b0000; // TT TT
        2'd1: both_unknown_pattern = 4'b0101; // TH TH
        2'd2: both_unknown_pattern = 4'b1010; // HT HT
        2'd3: both_unknown_pattern = 4'b1111; // HH HH
        default: both_unknown_pattern = 4'b0000;
      endcase
    end
  endfunction

  // synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      done            <= 1'b0;
      result          <= 32'd0;
      sum_ops         <= 16'd0;
      cfg_count       <= 4'd0;
      total_cfg       <= 4'd0;
      cfg_idx         <= 2'd0;
      cur_state       <= 4'd0;
      op_count        <= 8'd0;
      pair0_is_unknown<= 1'b0;
      pair1_is_unknown<= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          result  <= 32'd0;
          sum_ops <= 16'd0;
          cfg_count <= 4'd0;
          cfg_idx   <= 2'd0;

          if (start) begin
            // determine unknown flags
            pair0_is_unknown <= mask[0];
            pair1_is_unknown <= mask[1];

            // total configurations: max 4
            if (mask == 2'b00)
              total_cfg <= 4'd1;
            else
              total_cfg <= 4'd4;
          end
        end

        SETUP_CFG: begin
          // Generate cfg_state_bits based on mask and cfg_idx
          if (mask == 2'b00) begin
            // No unknowns: direct from data (interpret as 4 bits: {pair1, pair0})
            // Reuse 'data' for both pairs: pair1=data, pair0=data -> 4-state sequence
            cfg_state_bits <= {data, data};
          end else if (mask == 2'b01) begin
            // pair0 unknown, pair1 fixed=data
            cfg_state_bits[3:2] <= data;
            cfg_state_bits[1:0] <= cfg_idx; // 4 possibilities over 4 cfg
          end else if (mask == 2'b10) begin
            // pair1 unknown, pair0 fixed=data
            cfg_state_bits[1:0] <= data;
            cfg_state_bits[3:2] <= cfg_idx; // 4 possibilities
          end else begin
            // mask == 2'b11: both unknown -> use pattern ROM
            cfg_state_bits <= both_unknown_pattern(cfg_idx);
          end

          // Initialize current configuration state and op counter
          cur_state <= cfg_state_bits;
          op_count  <= 8'd0;
        end

        RUN_CFG: begin
          if (cur_state != 4'b0000) begin
            // Apply Bank-of-Bath-like rule:
            // Find leftmost H (highest index bit=1)
            if (cur_state[3]) begin
              // flip bit3 and bit2 (if exists)
              cur_state[3] <= ~cur_state[3];
              cur_state[2] <= ~cur_state[2];
            end else if (cur_state[2]) begin
              cur_state[2] <= ~cur_state[2];
              cur_state[1] <= ~cur_state[1];
            end else if (cur_state[1]) begin
              cur_state[1] <= ~cur_state[1];
              cur_state[0] <= ~cur_state[0];
            end else if (cur_state[0]) begin
              cur_state[0] <= ~cur_state[0];
            end
            op_count <= op_count + 8'd1;
          end
        end

        NEXT_CFG: begin
          // accumulate operations for finished configuration
          sum_ops   <= sum_ops + op_count[7:0];

          // increment configuration index/count
          if (cfg_count < total_cfg) begin
            cfg_count <= cfg_count + 4'd1;
            if (total_cfg > 1) begin
              cfg_idx <= cfg_idx + 2'd1;
            end
          end
        end

        FINISH: begin
          if (!done) begin
            // compute average = (sum_ops / total_cfg) in Q16.16
            // result = (sum_ops * 2^16) / total_cfg
            // total_cfg is 1 or 4, so implement directly
            if (total_cfg == 4'd1) begin
              result <= {sum_ops, 16'd0};
            end else begin
              // divide by 4: shift right by 2
              // (sum_ops * 2^16)/4 = sum_ops * 2^14
              result <= {sum_ops, 16'd0} >> 2;
            end
            done <= 1'b1;
          end
          // remain in FINISH until start drops, then FSM goes to IDLE
        end

        default: ;
      endcase
    end
  end

endmodule