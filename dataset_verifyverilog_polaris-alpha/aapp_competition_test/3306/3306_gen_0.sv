module minimal_phone_calls(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] M,
  input [15:0] P0,
  input [31:0] C0,
  input [15:0] P1,
  input [31:0] C1,
  input [15:0] P2,
  input [31:0] C2,
  input [15:0] P3,
  input [31:0] C3,
  input [15:0] P4,
  input [31:0] C4,
  input [15:0] P5,
  input [31:0] C5,
  input [15:0] P6,
  input [31:0] C6,
  input [15:0] P7,
  input [31:0] C7,
  output reg [31:0] result,
  output reg done
);

  // Internal registers for latched inputs
  reg [3:0]    n_reg;
  reg [15:0]   m_reg;
  reg [15:0]   P [0:7];
  reg [31:0]   C [0:7];

  // Sorting registers
  reg [5:0]    sort_step;      // 0..27 for 28 bubble-sort steps
  reg          sorting;

  // Cycle tracking to ensure result at exactly 100 cycles after start
  reg [6:0]    cycle_cnt;      // counts 0..100
  reg          busy;

  // Comparator temporary wires
  integer i_idx, j_idx;
  reg [2:0] idx_a, idx_b;
  reg [15:0] P_a, P_b;
  reg [31:0] C_a, C_b;

  // State for minimal calls computation
  reg [31:0] max_calls;
  reg [31:0] diff;

  // Control of sequence
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg      <= 4'd0;
      m_reg      <= 16'd0;
      P[0]       <= 16'd0; P[1] <= 16'd0; P[2] <= 16'd0; P[3] <= 16'd0;
      P[4]       <= 16'd0; P[5] <= 16'd0; P[6] <= 16'd0; P[7] <= 16'd0;
      C[0]       <= 32'd0; C[1] <= 32'd0; C[2] <= 32'd0; C[3] <= 32'd0;
      C[4]       <= 32'd0; C[5] <= 32'd0; C[6] <= 32'd0; C[7] <= 32'd0;
      sort_step  <= 6'd0;
      sorting    <= 1'b0;
      cycle_cnt  <= 7'd0;
      busy       <= 1'b0;
      result     <= 32'd0;
      done       <= 1'b0;
      max_calls  <= 32'd0;
      diff       <= 32'd0;
    end else begin
      done <= 1'b0;

      // Start sequence on start pulse when not busy
      if (start && !busy) begin
        // Latch inputs
        n_reg <= (N > 4'd8) ? 4'd8 : ((N == 4'd0) ? 4'd1 : N);
        m_reg <= M;
        P[0]  <= P0; C[0] <= C0;
        P[1]  <= P1; C[1] <= C1;
        P[2]  <= P2; C[2] <= C2;
        P[3]  <= P3; C[3] <= C3;
        P[4]  <= P4; C[4] <= C4;
        P[5]  <= P5; C[5] <= C5;
        P[6]  <= P6; C[6] <= C6;
        P[7]  <= P7; C[7] <= C7;

        // Initialize control
        sort_step <= 6'd0;
        sorting   <= 1'b1;
        cycle_cnt <= 7'd0;
        busy      <= 1'b1;
        max_calls <= 32'd0;
      end else if (busy) begin
        // Advance cycle counter
        if (cycle_cnt < 7'd100)
          cycle_cnt <= cycle_cnt + 7'd1;

        // Bubble sort for first n_reg detectors, one compare-swap per cycle
        if (sorting && (n_reg > 4'd1)) begin
          if (sort_step < 6'd28) begin
            // Map sort_step [0..27] to (i,j) pairs for bubble sort
            // Precomputed loop unrolling for N<=8
            // Using full 8-size network; we will mask swaps with n_reg
            case (sort_step)
              6'd0:  begin i_idx = 0; j_idx = 1; end
              6'd1:  begin i_idx = 1; j_idx = 2; end
              6'd2:  begin i_idx = 2; j_idx = 3; end
              6'd3:  begin i_idx = 3; j_idx = 4; end
              6'd4:  begin i_idx = 4; j_idx = 5; end
              6'd5:  begin i_idx = 5; j_idx = 6; end
              6'd6:  begin i_idx = 6; j_idx = 7; end
              6'd7:  begin i_idx = 0; j_idx = 1; end
              6'd8:  begin i_idx = 1; j_idx = 2; end
              6'd9:  begin i_idx = 2; j_idx = 3; end
              6'd10: begin i_idx = 3; j_idx = 4; end
              6'd11: begin i_idx = 4; j_idx = 5; end
              6'd12: begin i_idx = 5; j_idx = 6; end
              6'd13: begin i_idx = 0; j_idx = 1; end
              6'd14: begin i_idx = 1; j_idx = 2; end
              6'd15: begin i_idx = 2; j_idx = 3; end
              6'd16: begin i_idx = 3; j_idx = 4; end
              6'd17: begin i_idx = 4; j_idx = 5; end
              6'd18: begin i_idx = 0; j_idx = 1; end
              6'd19: begin i_idx = 1; j_idx = 2; end
              6'd20: begin i_idx = 2; j_idx = 3; end
              6'd21: begin i_idx = 3; j_idx = 4; end
              6'd22: begin i_idx = 0; j_idx = 1; end
              6'd23: begin i_idx = 1; j_idx = 2; end
              6'd24: begin i_idx = 2; j_idx = 3; end
              6'd25: begin i_idx = 0; j_idx = 1; end
              6'd26: begin i_idx = 1; j_idx = 2; end
              6'd27: begin i_idx = 0; j_idx = 1; end
              default: begin i_idx = 0; j_idx = 1; end
            endcase

            idx_a = i_idx[2:0];
            idx_b = j_idx[2:0];

            // Only operate if indices are within n_reg range
            if ((idx_a < n_reg) && (idx_b < n_reg)) begin
              P_a = P[idx_a];
              P_b = P[idx_b];
              C_a = C[idx_a];
              C_b = C[idx_b];

              if (P_a > P_b) begin
                // swap
                P[idx_a] <= P_b;
                P[idx_b] <= P_a;
                C[idx_a] <= C_b;
                C[idx_b] <= C_a;
              end
            end

            sort_step <= sort_step + 6'd1;
          end else begin
            sorting <= 1'b0; // sorting complete
          end
        end

        // Once sorting is done, compute minimal calls.
        // We do this combinationally within the cycle after sorting completes.
        if (!sorting) begin
          // Compute max(C_i) and max(C_{i+1} - C_i)
          integer k;
          reg [31:0] max_c_val;
          reg [31:0] max_gap;

          max_c_val = 32'd0;
          max_gap   = 32'd0;

          if (n_reg != 4'd0) begin
            for (k = 0; k < 8; k = k + 1) begin
              if (k < n_reg) begin
                if (C[k] > max_c_val)
                  max_c_val = C[k];
                if ((k+1) < n_reg) begin
                  if (C[k+1] >= C[k])
                    diff = C[k+1] - C[k];
                  else
                    diff = 32'd0;
                  if (diff > max_gap)
                    max_gap = diff;
                end
              end
            end
          end

          max_calls <= (max_c_val >= max_gap) ? max_c_val : max_gap;
        end

        // At cycle 100 after start, finalize result and assert done
        if (cycle_cnt == 7'd100) begin
          result <= max_calls;
          done   <= 1'b1;
          busy   <= 1'b0;
        end
      end
    end
  end

endmodule