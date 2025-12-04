module beautiful_number (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [3:0] digits [0:7],
  output reg [3:0] y_digits [0:7],
  output reg done
);

  typedef enum logic [2:0] {
    STATE_IDLE     = 3'b000,
    STATE_LOAD     = 3'b001,
    STATE_COMPARE  = 3'b010,
    STATE_INC1     = 3'b011, // increment k-digit prefix (phase 1)
    STATE_INC2     = 3'b100, // increment k-digit prefix (phase 2)
    STATE_GENERATE = 3'b101  // generate final beautiful number (1 cycle)
  } state_t;

  state_t curr_state, next_state;

  // Registered inputs and internal working copies
  reg [2:0] n_r, k_r;
  reg [3:0] in_digits_r [0:7];     // x (original number)
  reg [3:0] prefix_r [0:7];        // current candidate for first k digits
  reg [3:0] out_r [0:7];           // y output (valid when done=1)
  reg need_inc_r;                  // 1 if replicated pattern < x (increment required)
  reg running_r;                   // pipeline busy flag

  // Helper tasks/functions (combinational)
  function automatic bit geq (input [3:0] a [0:7], input [3:0] b [0:7], input [2:0] len);
    integer i;
    for (i = len - 1; i >= 0; i--) begin
      if (a[i] > b[i]) return 1'b1;
      if (a[i] < b[i]) return 1'b0;
    end
    return 1'b1; // equal
  endfunction

  function automatic void increment_prefix (input [3:0] a [0:7],
                                            input [2:0] k_in,
                                            output [3:0] res [0:7],
                                            output bit carry_out);
    integer i;
    carry_out = 1'b1; // start with +1
    for (i = 0; i < 8; i++) begin
      if (i < k_in) begin
        if (carry_out) begin
          if (a[i] == 4'd9) begin
            res[i] = 4'd0;
            carry_out = 1'b1;
          end else begin
            res[i] = a[i] + 1'b1;
            carry_out = 1'b0;
          end
        end else begin
          res[i] = a[i];
        end
      end else begin
        res[i] = 4'd0; // pad rest with zero for safety
      end
    end
  endfunction

  function automatic void replicate_pattern (input [3:0] prefix [0:7],
                                             input [2:0] k_in,
                                             input [2:0] n_in,
                                             output [3:0] out [0:7]);
    integer i;
    for (i = 0; i < 8; i++) begin
      if (i < n_in) out[i] = prefix[i % k_in];
      else out[i] = 4'd0;
    end
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_state   <= STATE_IDLE;
      running_r    <= 1'b0;
      need_inc_r   <= 1'b0;
      n_r          <= 3'd0;
      k_r          <= 3'd0;
      done         <= 1'b0;
      // Clear arrays
      for (int j = 0; j < 8; j++) begin
        in_digits_r[j] <= 4'd0;
        prefix_r[j]    <= 4'd0;
        out_r[j]       <= 4'd0;
        y_digits[j]    <= 4'd0;
      end
    end else begin
      curr_state <= next_state;
      done <= 1'b0; // default each cycle; set in STATE_GENERATE

      // Pipeline staging and operations
      case (curr_state)
        STATE_IDLE: begin
          running_r <= 1'b0;
          need_inc_r <= 1'b0;
        end

        STATE_LOAD: begin
          // Load inputs and initialize prefix to first k digits
          n_r <= n;
          k_r <= k;
          for (int j = 0; j < 8; j++) in_digits_r[j] <= digits[j];
          for (int j = 0; j < 8; j++) begin
            if (j < k) prefix_r[j] <= digits[j];
            else       prefix_r[j] <= 4'd0;
          end
        end

        STATE_COMPARE: begin
          // Compute need_inc_r = (replicate(prefix, k, n) < in_digits_r)
          begin
            [3:0] temp_pat [0:7];
            replicate_pattern(prefix_r, k_r, n_r, temp_pat);
            need_inc_r <= ~geq(temp_pat, in_digits_r, n_r);
          end
        end

        STATE_INC1: begin
          // Phase 1 of increment
          if (need_inc_r) begin
            [3:0] inc_res [0:7];
            bit carry;
            increment_prefix(prefix_r, k_r, inc_res, carry);
            // If carry out of k digits, we keep the wrapped result; replication handles it.
            for (int j = 0; j < 8; j++) prefix_r[j] <= (j < k_r) ? inc_res[j] : 4'd0;
          end
          // if not needed, keep prefix unchanged (not necessary but explicit)
          if (!need_inc_r) begin
            for (int j = 0; j < 8; j++) prefix_r[j] <= (j < k_r) ? prefix_r[j] : 4'd0;
          end
        end

        STATE_INC2: begin
          // Phase 2: ensure next state sees stable prefix (no operation)
        end

        STATE_GENERATE: begin
          // Final pattern becomes output y_digits
          begin
            [3:0] final_pat [0:7];
            replicate_pattern(prefix_r, k_r, n_r, final_pat);
            for (int j = 0; j < 8; j++) out_r[j] <= final_pat[j];
          end
          done <= 1'b1;
        end
      endcase

      // Drive outputs (registered)
      for (int j = 0; j < 8; j++) y_digits[j] <= out_r[j];

      // Running flag (to block new starts while pipeline is busy)
      case (next_state)
        STATE_IDLE:     running_r <= 1'b0;
        STATE_LOAD:     running_r <= 1'b1;
        default:        running_r <= 1'b1;
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = curr_state;
    case (curr_state)
      STATE_IDLE: begin
        if (start) next_state = STATE_LOAD;
      end
      STATE_LOAD: begin
        next_state = STATE_COMPARE;
      end
      STATE_COMPARE: begin
        // If replicated pattern >= original, skip increment phases
        if (need_inc_r) next_state = STATE_INC1;
        else            next_state = STATE_GENERATE;
      end
      STATE_INC1: begin
        next_state = STATE_INC2;
      end
      STATE_INC2: begin
        next_state = STATE_GENERATE;
      end
      STATE_GENERATE: begin
        next_state = STATE_IDLE;
      end
    endcase
  end

  // Constraints: k must be in [1, n) and n in [3, 8]
  // The design naturally works for all k < n; if k >= n, pattern repeats every k>n which still satisfies b[i]=b[i%k] but semantics may differ.

endmodule
