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

  // Local parameters
  localparam NUM_TOKENS = 16;
  localparam TOKEN_W    = 6;
  localparam MAX_BANKS  = 4;
  localparam MAX_VARS   = 16; // cap at 16 variables

  // State machine states
  localparam IDLE        = 2'b00;
  localparam PARSE       = 2'b01;
  localparam CALC_COST   = 2'b10;
  localparam DONE        = 2'b11;

  // Token types
  localparam TOK_V = 2'b00; // variable
  localparam TOK_R = 2'b01; // read
  localparam TOK_E = 2'b10; // loop marker

  // Internal signals and registers
  reg [1:0] state, next_state;
  reg [3:0] elements_parsed;
  reg [95:0] program_reg;

  // Internal program representation: type (2b) + value (4b) per token
  reg [5:0] prog [0:NUM_TOKENS-1];
  reg [3:0] prog_val [0:NUM_TOKENS-1];

  // Loop stack (max 4 nested)
  reg [31:0] loop_count_stack [0:3];
  reg [31:0] loop_cost_stack  [0:3];
  reg [2:0] loop_depth;
  reg [31:0] prog_cost_acc;     // cost accrued outside the deepest open loop
  reg [31:0] current_loop_body_cost; // cost accrued since the most recent 'E' start
  reg [31:0] total_cost_candidate;   // candidate total cost (post-shift-add for completed loops)

  // Current mapping being evaluated
  reg [1:0] bank_of_var [0:MAX_VARS-1]; // maps var idx (0..15) -> bank (0..3)
  reg [1:0] last_bank;                  // last bank touched (for BSR cost)
  reg [3:0] next_map_idx;               // enumeration index for mapping
  reg [31:0] min_cost;                  // best cost found
  reg [1:0] prev_bank;                  // previous token bank (for current token cost)
  reg cost_done;                        // mapping evaluation finished
  reg [3:0] map_max_idx;                // how many mappings to evaluate = P(b, min(s_max, 4))

  // Cycle counter for latency requirement
  reg [7:0] cycle_cnt; // enough for 256 cycles

  // State update
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Cycle counter and done flag update (synchronous)
  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_cnt <= 8'd0;
      done      <= 1'b0;
      min_instructions <= 32'd0;
    end else begin
      // Start of computation: reset latency counter
      if (state == IDLE && start) begin
        cycle_cnt <= 8'd1;
      end else if (state != IDLE) begin
        cycle_cnt <= cycle_cnt + 1;
      end

      // hold min_instructions when done, update on DONE
      if (state == DONE) begin
        done <= 1'b1;
        min_instructions <= min_cost;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Program register (for instrumentation if needed)
  always @(posedge clk) begin
    if (state == IDLE && start) begin
      program_reg <= program;
    end
  end

  // Parse program into arrays
  integer i;
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_TOKENS; i = i + 1) begin
        prog[i]    <= 6'd0;
        prog_val[i]<= 4'd0;
      end
      elements_parsed <= 4'd0;
    end else begin
      if (state == PARSE) begin
        if (elements_parsed < NUM_TOKENS) begin
          prog[elements_parsed]    <= program_reg[95 - (elements_parsed*6) -: 6];
          prog_val[elements_parsed]<= program_reg[95 - (elements_parsed*6) -: 6][3:0];
          elements_parsed          <= elements_parsed + 1;
        end
      end else if (state == IDLE) begin
        elements_parsed <= 4'd0;
      end
    end
  end

  // Main FSM and computation logic
  always @(*) begin
    // Defaults for next-state control signals
    next_state = state;
    cost_done  = 1'b0;

    // Combinational part of cost evaluation logic inside CALC_COST
    if (state == CALC_COST) begin
      if (!cost_done) begin
        // Perform one token evaluation step
        if (next_map_idx < map_max_idx) begin
          // Evaluate one token at prog_elem
          if (prog_elem < elements_parsed) begin
            // token type
            case (prog[prog_elem][5:4])
              TOK_V, TOK_R: begin
                // Determine current token's bank
                prev_bank = last_bank;
                if (prog[prog_elem][5:4] == TOK_V) begin
                  last_bank = bank_of_var[prog_val[prog_elem]];
                end else begin
                  last_bank = bank_of_var[prog_val[prog_elem]];
                end

                // Add BSR cost if bank changed
                if (prev_bank != last_bank) begin
                  total_cost_candidate = total_cost_candidate + 1;
                end

                // Prepare for next token
                prog_elem = prog_elem + 1;
                current_loop_body_cost = current_loop_body_cost + ((prev_bank != last_bank) ? 1 : 0);
              end
              TOK_E: begin
                if (prog_val[prog_elem] > 0) begin
                  // Start of a loop (iteration count > 0)
                  if (loop_depth < 4) begin
                    loop_cost_stack[loop_depth]  = current_loop_body_cost;
                    loop_count_stack[loop_depth] = prog_val[prog_elem];
                    loop_depth                   = loop_depth + 1;
                    // Reset body cost for the loop body
                    current_loop_body_cost = 32'd0;
                    prog_elem = prog_elem + 1;
                  end else begin
                    // Exceeded max nesting: treat as no-op to remain in spec
                    prog_elem = prog_elem + 1;
                  end
                end else begin
                  // Iteration count 0: no effect
                  prog_elem = prog_elem + 1;
                end
              end
              default: begin
                // Should not occur; skip token to avoid deadlock
                prog_elem = prog_elem + 1;
              end
            endcase
          end else begin
            // Program body fully scanned
            // Incorporate any remaining open loop costs
            if (loop_depth > 0) begin
              // pop the innermost loop
              loop_depth = loop_depth - 1;
              // loop body cost excludes the part already accumulated after it started
              // but includes the part accumulated inside the loop body (current_loop_body_cost)
              // So here we just multiply the body part with the count and add to total
              total_cost_candidate = total_cost_candidate + (current_loop_body_cost * loop_count_stack[loop_depth]);
              // now we are back to the outer context: its "body" cost resumes
              current_loop_body_cost = loop_cost_stack[loop_depth];
            end else begin
              // No open loops: mapping evaluation complete
              if (total_cost_candidate < min_cost) begin
                min_cost = total_cost_candidate;
              end
              next_map_idx = next_map_idx + 1;
              // Prepare for next mapping
              prog_elem    = 4'd0;
              last_bank    = 2'd0;
              total_cost_candidate = 32'd0;
              current_loop_body_cost = 32'd0;
            end
          end
        end else begin
          // All mappings evaluated
          cost_done = 1'b1;
        end
      end

      // State transitions
      if (cost_done) begin
        if (cycle_cnt >= 8'd255) begin
          next_state = DONE;
        end
      end
    end
  end

  // Sequential control for entering states, and step-by-step iteration management
  reg [3:0] prog_elem; // element index for cost evaluation
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset evaluation registers
      prog_elem    <= 4'd0;
      last_bank    <= 2'd0;
      prev_bank    <= 2'd0;
      total_cost_candidate <= 32'd0;
      current_loop_body_cost <= 32'd0;
      loop_depth   <= 3'd0;
      // Reset mapping and cost tracking
      next_map_idx <= 4'd0;
      min_cost     <= 32'hFFFFFFFF;
      map_max_idx  <= 4'd0;
      // Reset array (not strictly necessary, but keep simulator sane)
      for (i = 0; i < MAX_VARS; i = i + 1) bank_of_var[i] <= 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        loop_count_stack[i] <= 32'd0;
        loop_cost_stack[i]  <= 32'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          // On start, load inputs and initialize
          if (start) begin
            // Initialize for a new run
            next_map_idx <= 4'd0;
            min_cost     <= 32'hFFFFFFFF;
            prog_elem    <= 4'd0;
            last_bank    <= 2'd0;
            prev_bank    <= 2'd0;
            total_cost_candidate <= 32'd0;
            current_loop_body_cost <= 32'd0;
            loop_depth   <= 3'd0;
            // Reset stacks
            for (i = 0; i < 4; i = i + 1) begin
              loop_count_stack[i] <= 32'd0;
              loop_cost_stack[i]  <= 32'd0;
            end
            // Prepare mapping count: permutations of banks b taken min(s,4) at a time
            if ((b == 4'd0) || (s == 4'd0)) begin
              map_max_idx <= 4'd1; // special case will produce 0 cost later
            end else begin
              // P(b, k) where k = min(s, 4)
              if (s >= 4) begin
                // b * (b-1) * (b-2) * (b-3)
                map_max_idx <= b * (b - 1) * (b - 2) * (b - 3);
              end else begin
                // b * (b-1) * ... * (b-s+1)
                case (s)
                  4'd1: map_max_idx <= b;
                  4'd2: map_max_idx <= b * (b - 1);
                  4'd3: map_max_idx <= b * (b - 1) * (b - 2);
                  default: map_max_idx <= 4'd1; // should not occur
                endcase
              end
            end
          end
        end

        PARSE: begin
          // Waiting for parse to complete; remain here until elements_parsed == NUM_TOKENS
          if (elements_parsed == NUM_TOKENS) begin
            // Parse done -> prepare to compute cost
            prog_elem    <= 4'd0;
            last_bank    <= 2'd0;
            prev_bank    <= 2'd0;
            total_cost_candidate <= 32'd0;
            current_loop_body_cost <= 32'd0;
            loop_depth   <= 3'd0;
            // If there are no mappings, directly go to DONE (or set min cost = 0)
            if (map_max_idx == 4'd0) begin
              min_cost <= 32'd0;
            end
          end
        end

        CALC_COST: begin
          // If mapping enumeration is done, just wait for latency; otherwise step tokens already handled in comb block
          if (next_map_idx >= map_max_idx) begin
            // nothing to do here; will go DONE after latency
          end else begin
            // Nothing needed here; step logic is in combinational block
          end
        end

        DONE: begin
          // Hold outputs; wait for reset or new start
        end

        default: begin
          // Stay in current state
        end
      endcase
    end
  end

  // Enumerate next mapping: fed by mapping index
  // Mapping is a permutation of b banks taken k = min(s,4) at a time.
  // We generate arrays a0..a3 where aj = bank index used by variable j (0..3), 0 <= aj < b
  // This combinational block depends on next_map_idx; assign them to bank_of_var[0..3]
  reg [1:0] a0, a1, a2, a3;
  reg [3:0] b_reg;
  reg [3:0] s_reg;
  reg [3:0] k_reg;
  reg [31:0] p0, p1, p2, p3; // base multipliers for mixed-radix

  always @(*) begin
    b_reg = b;
    s_reg = s;
    k_reg = (s_reg >= 4) ? 4 : s_reg;

    // Precompute the product terms (mixed-radix bases)
    p0 = (k_reg >= 1) ? b_reg : 1;
    p1 = (k_reg >= 2) ? (b_reg * (b_reg - 1)) : 1;
    p2 = (k_reg >= 3) ? (b_reg * (b_reg - 1) * (b_reg - 2)) : 1;
    p3 = (k_reg >= 4) ? (b_reg * (b_reg - 1) * (b_reg - 2) * (b_reg - 3)) : 1;

    // Mixed-radix decoding of next_map_idx into a0..a3
    // idx = a0 + a1*b + a2*b*(b-1) + a3*b*(b-1)*(b-2)
    a0 = next_map_idx % p0;
    a1 = (k_reg >= 2) ? ((next_map_idx / p0) % (b_reg)) : 2'd0;
    a2 = (k_reg >= 3) ? ((next_map_idx / p1) % (b_reg - 1)) : 2'd0;
    a3 = (k_reg >= 4) ? ((next_map_idx / p2) % (b_reg - 2)) : 2'd0;
  end

  // Assign the decoded mapping to bank_of_var[0..3]; higher indices get 0 (unused)
  always @(*) begin
    // Clear all first
    for (i = 0; i < MAX_VARS; i = i + 1) begin
      bank_of_var[i] = 2'd0;
    end
    // Apply mapped variables
    bank_of_var[0] = a0;
    if (k_reg >= 2) bank_of_var[1] = a1;
    if (k_reg >= 3) bank_of_var[2] = a2;
    if (k_reg >= 4) bank_of_var[3] = a3;
  end

  // State machine transition logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = PARSE;
        else       next_state = IDLE;
      end
      PARSE: begin
        if (elements_parsed == NUM_TOKENS) next_state = CALC_COST;
        else                               next_state = PARSE;
      end
      CALC_COST: begin
        if (next_map_idx >= map_max_idx) begin
          // Wait until 256 cycles after start; cycle_cnt is updated in sequential block
          if (cycle_cnt >= 8'd255) next_state = DONE;
          else                     next_state = CALC_COST;
        end else begin
          next_state = CALC_COST;
        end
      end
      DONE: begin
        // Stay in DONE until rst_n or a new start
        if (start && rst_n) next_state = IDLE;
        else                next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule