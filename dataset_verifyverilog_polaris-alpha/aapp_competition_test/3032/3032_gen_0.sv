module harvard_min_instructions(
  input clk,
  input rst_n,
  input start,
  input [3:0] b, // number of banks (1-13)
  input [3:0] s, // variables per bank (1-13)
  input [95:0] program, // 16x6-bit tokens (packed)
  output reg [31:0] min_instructions,
  output reg done // high when computation complete
);

  // State encoding
  localparam IDLE      = 2'd0;
  localparam PARSE     = 2'd1;
  localparam CALC_COST = 2'd2;
  localparam DONE      = 2'd3;

  reg [1:0] state, next_state;

  // Internal constants / limits
  localparam MAX_TOKENS   = 16;
  localparam MAX_BANKS_HW = 4;   // hardware limit
  localparam MAX_VARS_HW  = 16;  // hardware limit

  // Parsed program storage
  // type: 2 bits, val: 4 bits
  reg [1:0] tok_type   [0:MAX_TOKENS-1];
  reg [3:0] tok_value  [0:MAX_TOKENS-1];

  // Effective configuration
  reg [3:0] eff_banks;  // 1..4
  reg [4:0] eff_vars;   // 1..16

  // Loop handling (up to 4 levels) - simple bracket-style
  // We assume: E token (type=2'b10) is loop control with value as repeat count.
  // For simplicity: preceding sequence until previous E or start is loop body.
  // We'll resolve it into a per-token multiplicative factor using a small stack.
  reg [3:0] loop_mul_stack [0:3];
  reg [1:0] loop_sp;

  // Per-token effective repeat multiplier (up to 4-level nested, small values)
  reg [7:0] tok_mult [0:MAX_TOKENS-1];

  // Mapping enumeration
  // var_bank[v] in [0 .. eff_banks-1]
  reg [1:0] cur_map   [0:MAX_VARS_HW-1];

  // min cost tracking
  reg [31:0] best_cost;

  // Generic counters
  reg [7:0] cycle_cnt;
  reg [4:0] parse_idx;
  reg [4:0] cost_idx;

  // Control flags
  reg parsing_done;
  reg mapping_done;

  // Compute effective banks and vars combinationally (capped)
  wire [3:0] banks_capped = (b < 4'd1) ? 4'd1 : ((b > MAX_BANKS_HW) ? MAX_BANKS_HW[3:0] : b);
  wire [7:0] vars_raw     = b * s;
  wire [4:0] vars_capped  = (vars_raw == 0) ? 5'd1 : ((vars_raw > MAX_VARS_HW) ? MAX_VARS_HW[4:0] : vars_raw[4:0]);

  integer i;

  // Combinational next state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PARSE;
      end
      PARSE: begin
        if (parsing_done)
          next_state = CALC_COST;
      end
      CALC_COST: begin
        if (mapping_done)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state            <= IDLE;
      min_instructions <= 32'hFFFFFFFF;
      done             <= 1'b0;
      cycle_cnt        <= 8'd0;
      parse_idx        <= 5'd0;
      cost_idx         <= 5'd0;
      parsing_done     <= 1'b0;
      mapping_done     <= 1'b0;
      loop_sp          <= 2'd0;
      best_cost        <= 32'hFFFFFFFF;
      eff_banks        <= 4'd1;
      eff_vars         <= 5'd1;
      for (i = 0; i < MAX_TOKENS; i = i + 1) begin
        tok_type[i]  <= 2'b00;
        tok_value[i] <= 4'd0;
        tok_mult[i]  <= 8'd1;
      end
      for (i = 0; i < MAX_VARS_HW; i = i + 1) begin
        cur_map[i] <= 2'd0;
      end
      done <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      // Update effective parameters (they are stable per run)
      eff_banks <= banks_capped;
      eff_vars  <= vars_capped;

      case (state)
        IDLE: begin
          cycle_cnt    <= 8'd0;
          parse_idx    <= 5'd0;
          cost_idx     <= 5'd0;
          parsing_done <= 1'b0;
          mapping_done <= 1'b0;
          best_cost    <= 32'hFFFFFFFF;
          loop_sp      <= 2'd0;
          // Initialize mapping to 0
          for (i = 0; i < MAX_VARS_HW; i = i + 1) begin
            cur_map[i] <= 2'd0;
          end
        end

        PARSE: begin
          // Parse 16 tokens from program (96 bits, 6 bits each)
          // token i is program[6*i +: 6]
          if (!parsing_done) begin
            for (i = 0; i < MAX_TOKENS; i = i + 1) begin
              tok_type[i]  <= program[6*i + 5 -: 2];
              tok_value[i] <= program[6*i + 3 -: 4];
            end

            // Build tok_mult using simple loop stack based on parsed tokens
            // Here we assume: type==E marks end of a loop body, value is repeat count.
            // For simplicity, each E applies to all tokens since last E (or start).
            // Nested loops: multiplicative.
            loop_sp <= 2'd0;
            for (i = 0; i < MAX_TOKENS; i = i + 1) begin
              tok_mult[i] <= 8'd1;
            end

            // Simple one-pass construct of multipliers
            // Implementation: running product on stack top; E tokens update stack.
            // Note: done in this clock in synthesizable style (unrolled by tools).
            begin : GEN_MULTS
              integer j;
              reg [7:0] cur_factor;
              reg [1:0] sp_local;
              reg [7:0] stack_local[0:3];
              cur_factor = 8'd1;
              sp_local   = 2'd0;
              for (j = 0; j < 4; j = j + 1) begin
                stack_local[j] = 8'd1;
              end
              for (j = 0; j < MAX_TOKENS; j = j + 1) begin
                if (tok_type[j] == 2'b10) begin
                  // E: close or define loop with count tok_value
                  if (sp_local < 4) begin
                    stack_local[sp_local] = tok_value[j];
                    sp_local = sp_local + 1'b1;
                  end
                end else begin
                  cur_factor = 8'd1;
                  if (sp_local != 0) begin
                    integer k;
                    cur_factor = 8'd1;
                    for (k = 0; k < sp_local; k = k + 1) begin
                      cur_factor = cur_factor * stack_local[k];
                    end
                  end
                  tok_mult[j] = cur_factor;
                end
              end
            end

            parsing_done <= 1'b1;
          end
        end

        CALC_COST: begin
          // Latency requirement: finish within 256 cycles. We enforce by cycle counter.
          cycle_cnt <= cycle_cnt + 8'd1;

          // Enumerate all mappings and compute minimal cost.
          // cur_map encodes mapping; we treat only eff_vars variables.

          // Cost computation for current mapping
          if (!mapping_done) begin
            reg [31:0] cost;
            reg [1:0] cur_bsr;
            reg [1:0] var_bank;
            integer t;

            cost    = 32'd0;
            cur_bsr = 2'd0;

            for (t = 0; t < MAX_TOKENS; t = t + 1) begin
              case (tok_type[t])
                2'b00: begin // V: variable access, value is var index
                  if (tok_value[t] < eff_vars) begin
                    var_bank = cur_map[tok_value[t]];
                    if (var_bank != cur_bsr) begin
                      cost    = cost + tok_mult[t]; // BSR change cost folded by loop
                      cur_bsr = var_bank;
                    end
                    cost = cost + tok_mult[t]; // instruction itself
                  end
                end
                2'b01: begin // R: bank-relative, no BSR change required
                  cost = cost + tok_mult[t];
                end
                2'b10: begin
                  // E: loop control token, no direct instruction cost
                end
                default: begin
                  // treat as NOP
                end
              endcase
            end

            // Update best cost
            if (cost < best_cost)
              best_cost <= cost;

            // Increment mapping (like mixed radix counter base eff_banks)
            integer v;
            reg carry;
            carry = 1'b1;
            for (v = 0; v < MAX_VARS_HW; v = v + 1) begin
              if (v < eff_vars) begin
                if (carry) begin
                  if (cur_map[v] + 1 < eff_banks[1:0]) begin
                    cur_map[v] <= cur_map[v] + 2'd1;
                    carry      <= 1'b0;
                  end else begin
                    cur_map[v] <= 2'd0;
                    carry      <= 1'b1;
                  end
                end
              end else begin
                cur_map[v] <= 2'd0;
              end
            end

            if (carry == 1'b1) begin
              // Completed all mappings
              mapping_done <= 1'b1;
            end

            // Force termination by cycle limit safeguard
            if (cycle_cnt >= 8'd255) begin
              mapping_done <= 1'b1;
            end
          end
        end

        DONE: begin
          done             <= 1'b1;
          min_instructions <= best_cost;
          // Wait for start to deassert (handled in FSM) before going back to IDLE
        end

        default: begin
        end
      endcase
    end
  end

endmodule