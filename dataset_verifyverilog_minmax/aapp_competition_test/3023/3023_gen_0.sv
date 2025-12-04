module cake_partition_checker(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Number of candles (1-8)
  input [1:0] m, // Number of cuts (1-4)
  input [15:0] r, // Cake radius (0-65535)
  // Candle coordinates: 8 max, each has x[15:0], y[15:0]
  input [15:0] candle_x[0:7],
  input [15:0] candle_y[0:7],
  // Cut coefficients: 4 max, each has a[7:0], b[7:0], c[15:0]
  input [7:0] cut_a[0:3],
  input [7:0] cut_b[0:3],
  input [15:0] cut_c[0:3],
  output reg result, // 1=yes, 0=no
  output reg done // High when computation completes
);

  // FSM states
  localparam S_IDLE     = 2'b00;
  localparam S_COMPUTE  = 2'b01;
  localparam S_CHECK    = 2'b10;

  reg [1:0] state;
  reg [5:0] cycle;       // 0..25
  reg [7:0] cand_idx;    // 0..7
  reg [1:0] cut_idx;     // 0..3

  // Signature for each candle (4-bit, 1 per cut, 0=neg/zero, 1=positive)
  reg [3:0] sig [0:7];
  reg [7:0] sig_seen;    // bitmask of observed signatures (0..15)
  reg [7:0] dup;         // duplicate detect mask for current candle
  reg [7:0] seen;        // duplicates across all candles

  // 30-bit signed accumulator for ax + by + c
  reg signed [29:0] acc;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      cycle   <= 6'd0;
      cand_idx <= 8'd0;
      cut_idx <= 2'd0;
      sig_seen <= 8'd0;
      dup <= 8'd0;
      seen <= 8'd0;
      result <= 1'b0;
      done <= 1'b0;
      acc <= 30'd0;
      for (i = 0; i < 8; i = i + 1) begin
        sig[i] <= 4'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          result <= 1'b0;
          if (start) begin
            // Initialize for a new run
            cycle   <= 6'd0;
            cand_idx <= 8'd0;
            cut_idx <= 2'd0;
            sig_seen <= 8'd0;
            seen <= 8'd0;
            dup <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
              sig[i] <= 4'd0;
            end
            state <= S_COMPUTE;
          end
        end

        S_COMPUTE: begin
          if (cycle == 6'd0) begin
            // First cycle: clear signature for the current candle
            sig[cand_idx] <= 4'd0;
          end
          if (cycle == 6'd0 || cycle == 6'd5 || cycle == 6'd10 || cycle == 6'd15) begin
            cut_idx <= cycle[4:3]; // cycles 0,5,10,15 -> cut 0..3
          end else if (cycle == 6'd1 || cycle == 6'd6 || cycle == 6'd11 || cycle == 6'd16) begin
            // Multiply a*x
            acc <= $signed({1'b0, cut_a[cut_idx]}) * $signed({1'b0, candle_x[cand_idx]});
          end else if (cycle == 6'd2 || cycle == 6'd7 || cycle == 6'd12 || cycle == 6'd17) begin
            // Add b*y
            acc <= acc + $signed({1'b0, cut_b[cut_idx]}) * $signed({1'b0, candle_y[cand_idx]});
          end else if (cycle == 6'd3 || cycle == 6'd8 || cycle == 6'd13 || cycle == 6'd18) begin
            // Add c
            acc <= acc + $signed(cut_c[cut_idx]);
          end else if (cycle == 6'd4 || cycle == 6'd9 || cycle == 6'd14 || cycle == 6'd19) begin
            // Set the signature bit for this cut (1 if ax+by+c > 0)
            sig[cand_idx][cut_idx] <= acc[29] ? 1'b0 : 1'b1;
            acc <= 30'd0;
            if (cut_idx == m - 1) begin
              // After the last cut, proceed to next candle or to check
              if (cand_idx == n - 1) begin
                state <= S_CHECK;
              end else begin
                cand_idx <= cand_idx + 1;
              end
            end
          end
          if (cycle == 6'd19) begin
            state <= S_CHECK;
          end else begin
            cycle <= cycle + 1;
          end
        end

        S_CHECK: begin
          // One cycle per candle to check uniqueness of signatures
          if (cycle >= 6'd20 && cycle < (6'd20 + {4'b0, n})) begin
            cand_idx <= cycle - 6'd20;
            dup[sig[cand_idx]] <= 1'b1;
            seen[sig[cand_idx]] <= 1'b1;
            cycle <= cycle + 1;
          end else if (cycle < 6'd24) begin
            cycle <= cycle + 1;
          end else begin
            // Determine result: all signatures must be unique (no duplicates)
            // dup is set for the current candle; compare with previously seen for robustness
            result <= (seen & dup) == 8'd0;
            done <= 1'b1;
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule