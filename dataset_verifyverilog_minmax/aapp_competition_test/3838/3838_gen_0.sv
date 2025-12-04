module permutation_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] n, // permutation size (1-8)
  input [3:0] k, // number of moves (1-16)
  input [23:0] q, // permutation q[0:n-1] (3 bits per element, 8 elements)
  input [23:0] s, // target permutation s[0:n-1] (3 bits per element)
  output reg result, // 1=possible, 0=impossible
  output reg done // high when computation complete
);

  // Constants
  localparam MAX_N = 8;
  localparam MAX_K = 16;
  localparam IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10;

  // Internal signals
  reg [1:0] state;
  integer i, j;
  integer cnt;
  integer step;
  integer m, m_minus_1;
  integer id0, idm, idm_1;
  integer q_int_mem [0:MAX_N-1];
  integer s_int_mem [0:MAX_N-1];

  // Decode 24-bit packed q (8 elements x 3 bits each) and s into arrays of integers [0..7]
  function [31:0] decode3 (input [23:0] pack, input [2:0] idx);
    decode3 = pack[3*idx +: 3];
  endfunction

  function [31:0] apply_perm_int (input integer src [0:MAX_N-1], input integer perm [0:MAX_N-1], input integer n_elem);
    integer arr [0:MAX_N-1];
    integer outv;
    begin
      for (i = 0; i < MAX_N; i = i + 1) begin
        if (i < n_elem) begin
          arr[i] = src[perm[i]];
        end else begin
          arr[i] = i; // unused entries map to identity
        end
      end
      // Convert packed representation of arr (3 bits per element) into single integer value
      outv = 0;
      for (i = 0; i < MAX_N; i = i + 1) begin
        if (i < n_elem) begin
          outv = outv + (arr[i] << (3*i));
        end
      end
      apply_perm_int = outv;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 1'b0;
      done <= 1'b0;
      for (i = 0; i < MAX_N; i = i + 1) begin
        q_int_mem[i] <= 0;
        s_int_mem[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Sample inputs
            for (i = 0; i < MAX_N; i = i + 1) begin
              q_int_mem[i] <= decode3(q, i[2:0]);
              s_int_mem[i] <= decode3(s, i[2:0]);
            end
            state <= RUN;
            result <= 1'b0; // default until computed
          end
        end

        RUN: begin
          // Start computation at the beginning of RUN cycle
          // Check all conditions to determine if s is reachable exactly at k moves
          result <= 1'b0;
          done   <= 1'b0;

          // Count how many elements in range
          cnt = 0;
          for (i = 0; i < MAX_N; i = i + 1) begin
            if (i < n) begin
              if (q_int_mem[i] >= 0 && q_int_mem[i] < n) cnt = cnt + 1;
              if (s_int_mem[i] >= 0 && s_int_mem[i] < n) cnt = cnt + 0; // no-op, kept for readability
            end
          end

          // k must be within our 8-cycle window (n<=8). If k > 8, impossible by timing constraint.
          if (k <= 8 && n >= 1 && n <= MAX_N && cnt == n) begin
            m = k;
            m_minus_1 = (k >= 1) ? (k - 1) : 0;

            // Identity at step 0, m, m-1
            id0 = 0; for (i = 0; i < n; i = i + 1) id0 = id0 + (i << (3*i));
            idm = apply_perm_int(q_int_mem, q_int_mem, n); // q^m for m up to 8, computed via repeated mapping
            for (j = 1; j < m; j = j + 1) idm = apply_perm_int(q_int_mem, q_int_mem, n); // repeat m-1 more times
            idm_1 = apply_perm_int(q_int_mem, q_int_mem, n);
            for (j = 1; j < m_minus_1; j = j + 1) idm_1 = apply_perm_int(q_int_mem, q_int_mem, n);

            // Early match check: state at step (k-1) must not equal s
            // This is idm_1 for both sequences (a) and (b)
            // Also ensure initial state (identity) is not s
            // Then check s equals state at step k for either parity class
            // Parity: k%2==0 => sequence (a) = id_k == idm == identity
            //         k%2==1 => sequence (a) = id_k == q
            if ((id0 != s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21)) &&
                (idm_1 != s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21))) begin
              if (k[0] == 1'b0) begin
                // even k: sequence (a) state is identity, sequence (b) state is q^{-k}
                if ((idm == (s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21))) ||
                    (idm == (s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21)))) begin
                  result <= 1'b1;
                end
              end else begin
                // odd k: sequence (a) state is q, sequence (b) state is q^{-k}
                idm = apply_perm_int(q_int_mem, q_int_mem, n); // one extra application for odd k
                if ((idm == (s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21))) ||
                    (idm == (s_int_mem[0] + (s_int_mem[1] << 3) + (s_int_mem[2] << 6) + (s_int_mem[3] << 9) + (s_int_mem[4] << 12) + (s_int_mem[5] << 15) + (s_int_mem[6] << 18) + (s_int_mem[7] << 21)))) begin
                  result <= 1'b1;
                end
              end
            end
          end

          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
