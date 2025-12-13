module combination_generator(
  input  logic       clk,
  input  logic       rst_n,
  input  logic [1:0] combo_len,
  input  logic       start,
  output logic [5:0] current_combo,
  output logic [3:0] combo_count,
  output logic       done
);

  // Internal state
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_PRE1  = 2'b01,
    S_GEN   = 2'b10,
    S_POST  = 2'b11
  } state_t;

  state_t       state, next_state;
  logic [1:0]   len_reg;           // latched combo_len
  logic [1:0]   i0, i1, i2;        // indices for elements (0:Red,1:Green,2:Blue)
  logic [3:0]   total_combos;      // total number of combinations for current len
  logic [3:0]   count_reg;         // internal combo counter
  logic [4:0]   extra_cycles;      // cycles remaining in POST to meet 2*num_combos+3
  logic         gen_done;          // flag when all combos generated

  // Compute total_combos based on len_reg
  function automatic [3:0] f_total_combos(input logic [1:0] len);
    case (len)
      2'd1: f_total_combos = 4'd3;   // (R, G, B)
      2'd2: f_total_combos = 4'd6;   // (RR,RG,RB,GG,GB,BB)
      2'd3: f_total_combos = 4'd10;  // 3 multiset combinations of size 3 from 3 colors
      default: f_total_combos = 4'd0;
    endcase
  endfunction

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PRE1;      // cycle 0 after start: preparation
      end
      S_PRE1: begin
        // move to generation state; first combo will appear here
        next_state = S_GEN;
      end
      S_GEN: begin
        if (gen_done)
          next_state = S_POST;      // after last combo, go to POST
      end
      S_POST: begin
        if (extra_cycles == 0)
          next_state = S_IDLE;      // stay idle after exact latency satisfied
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      len_reg       <= 2'd0;
      i0            <= 2'd0;
      i1            <= 2'd0;
      i2            <= 2'd0;
      total_combos  <= 4'd0;
      count_reg     <= 4'd0;
      extra_cycles  <= 5'd0;
      current_combo <= 6'd0;
      combo_count   <= 4'd0;
      done          <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        // ---------------------------------------------------
        // IDLE: wait for start
        // ---------------------------------------------------
        S_IDLE: begin
          combo_count   <= 4'd0;
          current_combo <= 6'd0;
          count_reg     <= 4'd0;
          gen_done      <= 1'b0;
          extra_cycles  <= 5'd0;
          if (start) begin
            // latch length and initialize indices
            len_reg      <= (combo_len < 2'd1) ? 2'd1 : (combo_len > 2'd3) ? 2'd3 : combo_len;
            // all start at 0 ("Red") for lexicographically first combination
            i0           <= 2'd0;
            i1           <= 2'd0;
            i2           <= 2'd0;
            total_combos <= f_total_combos((combo_len < 2'd1) ? 2'd1 : (combo_len > 2'd3) ? 2'd3 : combo_len);
          end
        end

        // ---------------------------------------------------
        // PRE1: one-cycle prep; first combo will be output in S_GEN
        // ---------------------------------------------------
        S_PRE1: begin
          // Initialize generator indices for lexicographic combinations with repetition
          // For all valid lengths, start with minimal multiset: all zeros
          i0        <= 2'd0;
          i1        <= 2'd0;
          i2        <= 2'd0;
          count_reg <= 4'd0;
        end

        // ---------------------------------------------------
        // GEN: generate combinations, one per cycle
        // ---------------------------------------------------
        S_GEN: begin
          // Output current combination based on indices and length
          unique case (len_reg)
            2'd1: begin
              current_combo[1:0] <= i0;
              current_combo[5:2] <= 4'd0;
            end
            2'd2: begin
              current_combo[1:0] <= i0;
              current_combo[3:2] <= i1;
              current_combo[5:4] <= 2'd0;
            end
            2'd3: begin
              current_combo[1:0] <= i0;
              current_combo[3:2] <= i1;
              current_combo[5:4] <= i2;
            end
            default: begin
              current_combo <= 6'd0;
            end
          endcase

          // Update counters
          if (count_reg < total_combos) begin
            count_reg   <= count_reg + 4'd1;
            combo_count <= count_reg + 4'd1;
          end

          // Check if this was the last combo and prepare next indices
          if (count_reg + 4'd1 == total_combos) begin
            // Last combo just issued
            gen_done     <= 1'b1;
            done         <= 1'b1;  // done high for this last combo cycle
            // Prepare extra cycles to match 2*num_combos + 3 total
            // Already used: 1(start) + 1(PRE1) + total_combos(GEN)
            // Remaining = (2*total_combos + 3) - (2 + total_combos) = total_combos + 1
            extra_cycles <= total_combos + 4'd1;
          end else begin
            gen_done <= 1'b0;
            done     <= 1'b0;

            // Generate next lexicographic combination with repetition (colors 0..2)
            // Non-decreasing indices to ensure dictionary order over encoded values.
            if (len_reg == 2'd1) begin
              // Sequence: 0,1,2
              if (i0 < 2'd2) begin
                i0 <= i0 + 2'd1;
              end
            end else if (len_reg == 2'd2) begin
              // Non-decreasing pair (i0 <= i1)
              if (i1 < 2'd2) begin
                i1 <= i1 + 2'd1;
              end else begin
                i0 <= i0 + 2'd1;
                i1 <= i0 + 2'd1; // keep non-decreasing
              end
            end else begin
              // len_reg == 3: i0 <= i1 <= i2, colors 0..2
              if (i2 < 2'd2) begin
                i2 <= i2 + 2'd1;
              end else if (i1 < 2'd2) begin
                i1 <= i1 + 2'd1;
                i2 <= i1 + 2'd1;
              end else begin
                i0 <= i0 + 2'd1;
                i1 <= i0 + 2'd1;
                i2 <= i0 + 2'd1;
              end
            end
          end
        end

        // ---------------------------------------------------
        // POST: burn remaining cycles so total = 2*num_combos + 3
        // ---------------------------------------------------
        S_POST: begin
          // Hold last outputs; done already pulsed in GEN on final combo
          if (extra_cycles != 0) begin
            extra_cycles <= extra_cycles - 5'd1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule