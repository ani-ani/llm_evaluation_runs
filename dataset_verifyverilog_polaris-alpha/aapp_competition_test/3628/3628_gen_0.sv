module permutation_crypto(
  input              clk,
  input              rst_n,
  input              start,
  input      [3:0]   a [0:7],
  output reg [3:0]   pi [0:7],
  output reg [3:0]   sigma [0:7],
  output reg         valid,
  output reg         impossible,
  output reg         done
);

  // Internal registers
  reg [2:0] perm [0:7];           // current permutation candidate (0..7)
  reg [5:0] idx;                  // generic index / counter

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_CHECK_SIG = 3'd2,
    S_SIG_DONE  = 3'd3,
    S_NEXT_PERM = 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Flags and helpers
  reg [2:0] i_check;              // index for checking sigma permutation
  reg [7:0] used_mask;            // bitmask for used sigma values
  reg       conflict;             // conflict found while building sigma
  reg       has_next_perm;        // indicates if next permutation exists

  // sigma candidate (before commit to outputs)
  reg [2:0] sigma_cand [0:7];

  integer k;

  // Next permutation (lexicographic) logic - combinational, based on 'perm'
  // Generates 'next_perm' and 'has_next_perm'
  reg [2:0] next_perm [0:7];

  always @* begin
    // default: copy current permutation
    for (k = 0; k < 8; k = k + 1) begin
      next_perm[k] = perm[k];
    end
    has_next_perm = 1'b0;

    // Find rightmost index i with perm[i] < perm[i+1]
    integer i, j;
    i = -1;
    for (j = 0; j < 7; j = j + 1) begin
      if (perm[j] < perm[j+1])
        i = j;
    end

    if (i != -1) begin
      // Find rightmost index j > i with perm[j] > perm[i]
      integer jj;
      j = -1;
      for (jj = 0; jj < 8; jj = jj + 1) begin
        if (jj > i && perm[jj] > perm[i])
          j = jj;
      end

      if (j != -1) begin
        // Swap perm[i] and perm[j]
        reg [2:0] tmp;
        tmp = next_perm[i];
        next_perm[i] = next_perm[j];
        next_perm[j] = tmp;

        // Reverse from i+1 to end
        integer l, r;
        l = i + 1;
        r = 7;
        while (l < r) begin
          tmp = next_perm[l];
          next_perm[l] = next_perm[r];
          next_perm[r] = tmp;
          l = l + 1;
          r = r - 1;
        end

        has_next_perm = 1'b1;
      end
    end
  end

  // Sequential state and main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      valid       <= 1'b0;
      impossible  <= 1'b0;
      i_check     <= 3'd0;
      used_mask   <= 8'd0;
      conflict    <= 1'b0;

      for (k = 0; k < 8; k = k + 1) begin
        perm[k]       <= 3'd0;
        pi[k]         <= 4'd0;
        sigma[k]      <= 4'd0;
        sigma_cand[k] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          valid      <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            // Initialize first permutation to identity 0..7
            for (k = 0; k < 8; k = k + 1) begin
              perm[k] <= k[2:0];
            end
            i_check   <= 3'd0;
            used_mask <= 8'd0;
            conflict  <= 1'b0;
          end
        end

        S_INIT: begin
          // Prepare for sigma construction for current perm
          i_check   <= 3'd0;
          used_mask <= 8'd0;
          conflict  <= 1'b0;
        end

        S_CHECK_SIG: begin
          // For current i_check, compute sigma_i and check uniqueness
          // sigma_i = (a_i - pi_i) mod 8
          reg [3:0] ai;
          reg [2:0] pii;
          reg [2:0] sig_val;
          ai      = a[i_check];
          pii     = perm[i_check];
          sig_val = (ai[2:0] + (3'd8 - pii)) & 3'b111; // (a - pi) mod 8

          // Check if already used
          if (used_mask[sig_val]) begin
            conflict <= 1'b1;
          end else begin
            used_mask[sig_val] <= 1'b1;
            sigma_cand[i_check] <= sig_val;
          end

          // Increment index for next cycle (handled by state logic)
        end

        S_SIG_DONE: begin
          // If no conflict, commit pi and sigma outputs
          if (!conflict) begin
            integer t;
            for (t = 0; t < 8; t = t + 1) begin
              pi[t]    <= {1'b0, perm[t]};
              sigma[t] <= {1'b0, sigma_cand[t]};
            end
            valid <= 1'b1;
            done  <= 1'b1;
          end
        end

        S_NEXT_PERM: begin
          // Move to next permutation if exists
          if (has_next_perm) begin
            for (k = 0; k < 8; k = k + 1) begin
              perm[k] <= next_perm[k];
            end
            i_check   <= 3'd0;
            used_mask <= 8'd0;
            conflict  <= 1'b0;
          end else begin
            // No more permutations
            impossible <= 1'b1;
            done       <= 1'b1;
          end
        end

        S_DONE: begin
          // Hold results until next start (external logic can reset or restart)
          if (start) begin
            // Restart search on new start pulse
            done       <= 1'b0;
            valid      <= 1'b0;
            impossible <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
              perm[k] <= k[2:0];
            end
            i_check   <= 3'd0;
            used_mask <= 8'd0;
            conflict  <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  // Next-state combinational logic
  always @* begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_CHECK_SIG;
      end

      S_CHECK_SIG: begin
        if (conflict) begin
          // Early exit on conflict: go generate next permutation
          next_state = S_NEXT_PERM;
        end else if (i_check == 3'd7) begin
          // Last element processed with no conflict so far
          next_state = S_SIG_DONE;
        end else begin
          // Continue with next index
          next_state = S_CHECK_SIG;
        end
      end

      S_SIG_DONE: begin
        if (!conflict) begin
          // Found valid solution
          next_state = S_DONE;
        end else begin
          // Should not occur; conflict path handled earlier
          next_state = S_NEXT_PERM;
        end
      end

      S_NEXT_PERM: begin
        if (has_next_perm) begin
          next_state = S_INIT;
        end else begin
          // No more permutations, done with impossible
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        if (start)
          next_state = S_INIT;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // i_check update logic (separate to avoid multiple drivers)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_check <= 3'd0;
    end else begin
      if (state == S_INIT) begin
        i_check <= 3'd0;
      end else if (state == S_CHECK_SIG && !conflict && i_check != 3'd7) begin
        i_check <= i_check + 3'd1;
      end else if (state != S_CHECK_SIG) begin
        // Default hold or reset in other states as needed
      end
    end
  end

endmodule