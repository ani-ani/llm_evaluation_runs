module permutation_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] k,
  input [23:0] q,
  input [23:0] s,
  output reg result,
  output reg done
);

  // Internal signals
  reg [3:0] move_cnt;        // up to 16
  reg [2:0] cur_f [0:7];     // forward sequence current permutation
  reg [2:0] cur_b [0:7];     // backward (inverse) sequence current permutation
  reg [2:0] q_arr [0:7];     // q as array
  reg [2:0] q_inv [0:7];     // inverse of q
  reg [2:0] s_arr [0:7];     // s as array

  reg [2:0] nxt_f [0:7];
  reg [2:0] nxt_b [0:7];

  reg e0, e1; // e[0], e[1]
  reg f0, f1; // f[0], f[1]
  reg initial_equal;
  reg started;

  integer i;

  // Unpack q and s into arrays combinationally
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      q_arr[i] = q[i*3 +: 3];
      s_arr[i] = s[i*3 +: 3];
    end
  end

  // Compute q inverse combinationally
  always @* begin
    // default
    for (i = 0; i < 8; i = i + 1) begin
      q_inv[i] = 3'd0;
    end
    // q_arr: position i maps to q_arr[i]
    // inverse: position v has preimage i, so q_inv[v] = i
    for (i = 0; i < 8; i = i + 1) begin
      if (q_arr[i] < 8)
        q_inv[q_arr[i]] = i[2:0];
    end
  end

  // Check if initial (identity) equals s for given n
  always @* begin
    initial_equal = 1'b1;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        if (s_arr[i] != i[2:0])
          initial_equal = 1'b0;
      end else begin
        // positions beyond n are don't-care logically; force mismatch to avoid accidental equality
        if (s_arr[i] != 3'd0)
          initial_equal = 1'b0;
      end
    end
  end

  // Next permutations after applying q / q_inv to current ones
  always @* begin
    // forward: nxt_f[pos] = q_arr[ cur_f[pos] ]
    // backward: nxt_b[pos] = q_inv[ cur_b[pos] ]
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        nxt_f[i] = q_arr[cur_f[i]];
        nxt_b[i] = q_inv[cur_b[i]];
      end else begin
        nxt_f[i] = 3'd0;
        nxt_b[i] = 3'd0;
      end
    end
  end

  // FSM / sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      move_cnt <= 4'd0;
      e0 <= 1'b0;
      e1 <= 1'b0;
      f0 <= 1'b0;
      f1 <= 1'b0;
      result <= 1'b0;
      done <= 1'b0;
      started <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        cur_f[i] <= 3'd0;
        cur_b[i] <= 3'd0;
      end
    end else begin
      if (start && !started) begin
        // initialize
        started <= 1'b1;
        done <= 1'b0;
        result <= 1'b0;
        move_cnt <= 4'd0;

        // set initial permutations as identity
        for (i = 0; i < 8; i = i + 1) begin
          if (i < n) begin
            cur_f[i] <= i[2:0];
            cur_b[i] <= i[2:0];
          end else begin
            cur_f[i] <= 3'd0;
            cur_b[i] <= 3'd0;
          end
        end

        // initialize parity trackers
        // e[k%2], f[k%2] style: we track if s reached at even/odd steps
        e0 <= 1'b0;
        e1 <= 1'b0;
        f0 <= 1'b0;
        f1 <= 1'b0;
      end else if (started && !done) begin
        // perform one move per cycle
        // apply q to cur_f, and q_inv to cur_b
        for (i = 0; i < 8; i = i + 1) begin
          cur_f[i] <= nxt_f[i];
          cur_b[i] <= nxt_b[i];
        end

        // increment move counter
        move_cnt <= move_cnt + 4'd1;

        // compare with s after the move
        // forward match
        reg match_f;
        reg match_b;
        integer j;
        match_f = 1'b1;
        match_b = 1'b1;
        for (j = 0; j < 8; j = j + 1) begin
          if (j < n) begin
            if (nxt_f[j] != s_arr[j]) match_f = 1'b0;
            if (nxt_b[j] != s_arr[j]) match_b = 1'b0;
          end else begin
            // ensure no unintended match beyond n
            if (s_arr[j] != 3'd0) begin
              match_f = 1'b0;
              match_b = 1'b0;
            end
          end
        end

        // update parity flags based on new move_cnt+1 (even/odd)
        if ((move_cnt + 4'd1)[0] == 1'b0) begin
          // even index -> e0/f0
          if (match_f) e0 <= 1'b1;
          if (match_b) f0 <= 1'b1;
        end else begin
          // odd index -> e1/f1
          if (match_f) e1 <= 1'b1;
          if (match_b) f1 <= 1'b1;
        end

        // finish when reach k moves or 8 cycles max (per requirements)
        if ((move_cnt + 4'd1) == k || (move_cnt + 4'd1) == 4'd8) begin
          started <= 1'b0;
          done <= 1'b1;

          // parity-based acceptance similar to Python e[k%2]/f[k%2]
          // s must NOT equal initial, and must appear at step k in at least one sequence,
          // and must not appear earlier (captured via parity flags logic below).
          // Implement strict version:
          reg ok_forward;
          reg ok_backward;
          reg bad_early;

          ok_forward = 1'b0;
          ok_backward = 1'b0;
          bad_early = 1'b0;

          // If k is even: use e0/f0; if odd: e1/f1
          if (!k[0]) begin
            ok_forward = e0;
            ok_backward = f0;
          end else begin
            ok_forward = e1;
            ok_backward = f1;
          end

          // Earlier appearance check using opposite parity flags
          if (!k[0]) begin
            // k even => earlier odd steps use e1/f1
            if (e1 || f1) bad_early = 1'b1;
          end else begin
            // k odd => earlier even steps use e0/f0
            if (e0 || f0) bad_early = 1'b1;
          end

          if (!initial_equal && (ok_forward || ok_backward) && !bad_early && (k != 4'd0)) begin
            result <= 1'b1;
          end else begin
            result <= 1'b0;
          end
        end
      end else begin
        // idle
        if (!start) begin
          started <= 1'b0;
        end
      end
    end
  end

endmodule