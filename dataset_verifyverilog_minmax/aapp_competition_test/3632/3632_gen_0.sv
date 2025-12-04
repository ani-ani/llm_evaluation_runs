module composite_string_position (
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // initiate computation
  input [2:0] n, // number of initial strings (1-8)
  input [1:0] k, // number of concatenations (1-4)
  input [7:0][31:0] sorted_strings, // alphabetically sorted strings (unused)
  input [3:0][2:0] test_indices, // k indices for test composite (MSB first)
  output reg [15:0] position, // 1-based output position
  output reg done // high when result valid
);

  // State machine
  typedef enum logic {IDLE=1'b0, BUSY=1'b1} state_t;
  state_t state;

  // Internal signals
  logic start_pulse;
  logic [2:0] n_reg, k_reg;
  logic [7:0] used_mask;
  logic [2:0] i; // iteration index (0..3), also index into test_indices
  logic [15:0] rank_accum;
  logic [15:0] perm_look;
  logic [15:0] perm_val;
  logic [2:0] sel_idx;
  logic [2:0] less_count;

  // Edge detection for start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      // done is set BUSY->IDLE and held until next start
      done <= (state == BUSY) ? 1'b0 : (start_pulse ? 1'b0 : done);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_reg <= 3'd0;
      k_reg <= 2'd0;
      used_mask <= 8'd0;
      i <= 3'd0;
      rank_accum <= 16'd0;
      position <= 16'd0;
    end else begin
      // start pulse generation
      start_pulse <= start && (state == IDLE);

      case (state)
        IDLE: begin
          used_mask <= 8'd0;
          i <= 3'd0;
          rank_accum <= 16'd0;
          position <= position; // hold last valid value
          if (start_pulse) begin
            n_reg <= n;
            k_reg <= k;
            state <= BUSY;
          end
        end
        BUSY: begin
          // One cycle per selection
          n_reg <= n_reg;
          k_reg <= k_reg;
          // used_mask and i update in the same cycle based on current i

          // Count how many unused indices are less than the current test_indices[i]
          // Note: used_mask bit 'b' is 1 if index b has been used
          less_count <= $countones( (~used_mask) & (8'hFF >> (8 - n_reg)) & ( (8'hFE << sel_idx) ) );

          // Select current index (MSB first)
          case (i)
            3'd0: sel_idx <= test_indices[3];
            3'd1: sel_idx <= test_indices[2];
            3'd2: sel_idx <= test_indices[1];
            default: sel_idx <= test_indices[0];
          endcase

          // Accumulate rank contribution
          rank_accum <= rank_accum + (16'(less_count) * perm_look);

          // Mark the selected index as used
          used_mask <= used_mask | (8'b1 << sel_idx);

          // Move to next position
          if (i == (k_reg - 1)) begin
            // All selections done
            position <= rank_accum + (16'(less_count) * perm_look) + 16'd1; // add 1 for 1-based position
            state <= IDLE;
            i <= 3'd0;
            // used_mask cleared on next IDLE; leave as-is for now
          end else begin
            i <= i + 1;
            state <= BUSY;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Permutation lookup
  // perm_val = P(a, b) = a! / (a - b)!
  // a = n_reg - i - 1; b = k_reg - i - 1
  always_comb begin
    a = n_reg - i - 1;
    b = k_reg - i - 1;
    perm_val = 16'd0;
    case (a)
      3'd0: perm_val = (b == 3'd0) ? 16'd1 : 16'd0; // P(0,0)=1
      3'd1: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd1 : 16'd0); // P(1,0)=1, P(1,1)=1
      3'd2: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd2 : (b == 3'd2 ? 16'd2 : 16'd0)); // P(2,1)=2, P(2,2)=2
      3'd3: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd3 : (b == 3'd2 ? 16'd6 : (b == 3'd3 ? 16'd6 : 16'd0)));
      3'd4: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd4 : (b == 3'd2 ? 16'd12 : (b == 3'd3 ? 16'd24 : (b == 3'd4 ? 16'd24 : 16'd0))));
      3'd5: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd5 : (b == 3'd2 ? 16'd20 : (b == 3'd3 ? 16'd60 : (b == 3'd4 ? 16'd120 : (b == 3'd5 ? 16'd120 : 16'd0)))));
      3'd6: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd6 : (b == 3'd2 ? 16'd30 : (b == 3'd3 ? 16'd120 : (b == 3'd4 ? 16'd360 : (b == 3'd5 ? 16'd720 : (b == 3'd6 ? 16'd720 : 16'd0))))));
      3'd7: perm_val = (b == 3'd0) ? 16'd1 : (b == 3'd1 ? 16'd7 : (b == 3'd2 ? 16'd42 : (b == 3'd3 ? 16'd210 : (b == 3'd4 ? 16'd840 : (b == 3'd5 ? 16'd2520 : (b == 3'd6 ? 16'd5040 : (b == 3'd7 ? 16'd5040 : 16'd0)))))));
      default: perm_val = 16'd0;
    endcase
    perm_look = perm_val;
  end

endmodule
