module dinner_experiences(
  input clk,
  input rst_n,
  input start,
  input [2:0] r,
  input [2:0] s,
  input [2:0] m,
  input [2:0] d,
  input [1:0] n,
  input [3:0] brands [0:7],
  input [4:0] dish_ingredients [0:5][0:7],
  input [4:0] incompatible [0:1][0:1],
  output reg [63:0] result,
  output reg done
);

  localparam IDLE       = 2'd0;
  localparam COMB_CHECK = 2'd1;
  localparam BRAND_CALC = 2'd2;
  localparam DONE       = 2'd3;

  localparam [63:0] THRESHOLD = 64'd1000000000000000000; // 1e18

  reg [1:0] state, next_state;

  reg [2:0] s_idx, m_idx, d_idx;
  reg [2:0] next_s_idx, next_m_idx, next_d_idx;

  reg [63:0] total_experiences, next_total_experiences;

  reg [7:0] ingredient_mask, next_ingredient_mask;

  reg invalid_combination;

  reg [3:0] ci;
  reg [2:0] ing_idx;
  reg [63:0] combination_experiences;
  reg [63:0] next_combination_experiences;

  reg too_many;
  reg next_too_many;

  integer i;

  // Helper: check if dish index is starter/main/dessert
  function automatic bit is_starter(input [2:0] idx);
    begin
      is_starter = (idx < s);
    end
  endfunction

  function automatic bit is_main(input [2:0] idx);
    begin
      is_main = (idx < m);
    end
  endfunction

  function automatic bit is_dessert(input [2:0] idx);
    begin
      is_dessert = (idx < d);
    end
  endfunction

  // Map local combo indices to global dish indices: starters[0..s-1], mains[s..s+m-1], desserts[s+m..s+m+d-1]
  function automatic [2:0] starter_dish_idx(input [2:0] si);
    begin
      starter_dish_idx = si;
    end
  endfunction

  function automatic [2:0] main_dish_idx(input [2:0] mi);
    begin
      main_dish_idx = s + mi;
    end
  endfunction

  function automatic [2:0] dessert_dish_idx(input [2:0] di);
    begin
      dessert_dish_idx = s + m + di;
    end
  endfunction

  // Combinational next-state and control logic
  always @* begin
    next_state = state;
    next_s_idx = s_idx;
    next_m_idx = m_idx;
    next_d_idx = d_idx;
    next_total_experiences = total_experiences;
    next_ingredient_mask = ingredient_mask;
    next_combination_experiences = combination_experiences;
    next_too_many = too_many;

    invalid_combination = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMB_CHECK;
          next_s_idx = 3'd0;
          next_m_idx = 3'd0;
          next_d_idx = 3'd0;
          next_total_experiences = 64'd0;
          next_ingredient_mask = 8'd0;
          next_combination_experiences = 64'd0;
          next_too_many = 1'b0;
        end
      end

      COMB_CHECK: begin
        // Skip if indices exceed limits
        if (s_idx >= s || m_idx >= m || d_idx >= d) begin
          // Advance to next combination
          if (d_idx + 1 < d) begin
            next_d_idx = d_idx + 1;
          end else begin
            next_d_idx = 3'd0;
            if (m_idx + 1 < m) begin
              next_m_idx = m_idx + 1;
            end else begin
              next_m_idx = 3'd0;
              if (s_idx + 1 < s) begin
                next_s_idx = s_idx + 1;
              end else begin
                // All combinations done
                next_state = DONE;
              end
            end
          end
        end else begin
          // Valid index range: check incompatibilities
          invalid_combination = 1'b0;
          // Get actual dish indices
          ci = starter_dish_idx(s_idx);
          // ci is starter dish index
          // main index
          // we reuse local vars for dish indices
          // j: main dish index
          // k: dessert dish index
          // Use small regs
          reg [2:0] sd, md, dd;
          sd = starter_dish_idx(s_idx);
          md = main_dish_idx(m_idx);
          dd = dessert_dish_idx(d_idx);

          // Check each incompatible pair
          for (i = 0; i < 2; i = i + 1) begin
            if (i < n) begin
              if ((incompatible[i][0] == sd && incompatible[i][1] == md) ||
                  (incompatible[i][0] == md && incompatible[i][1] == sd) ||
                  (incompatible[i][0] == sd && incompatible[i][1] == dd) ||
                  (incompatible[i][0] == dd && incompatible[i][1] == sd) ||
                  (incompatible[i][0] == md && incompatible[i][1] == dd) ||
                  (incompatible[i][0] == dd && incompatible[i][1] == md)) begin
                invalid_combination = 1'b1;
              end
            end
          end

          if (invalid_combination) begin
            // Move to next combination directly
            if (d_idx + 1 < d) begin
              next_d_idx = d_idx + 1;
            end else begin
              next_d_idx = 3'd0;
              if (m_idx + 1 < m) begin
                next_m_idx = m_idx + 1;
              end else begin
                next_m_idx = 3'd0;
                if (s_idx + 1 < s) begin
                  next_s_idx = s_idx + 1;
                end else begin
                  next_state = DONE;
                end
              end
            end
          end else begin
            // Valid combination: prepare BRAND_CALC
            next_ingredient_mask = 8'd0;
            next_combination_experiences = 64'd1;
            next_state = BRAND_CALC;
          end
        end
      end

      BRAND_CALC: begin
        // Compute union of ingredients and product of brand counts
        // Get dish indices
        reg [2:0] sd, md, dd;
        sd = starter_dish_idx(s_idx);
        md = main_dish_idx(m_idx);
        dd = dessert_dish_idx(d_idx);

        // Build ingredient mask
        next_ingredient_mask = 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
          if (i < r) begin
            if (dish_ingredients[sd][i] != 5'd0)
              next_ingredient_mask[i] = 1'b1;
            if (dish_ingredients[md][i] != 5'd0)
              next_ingredient_mask[i] = 1'b1;
            if (dish_ingredients[dd][i] != 5'd0)
              next_ingredient_mask[i] = 1'b1;
          end
        end

        // Multiply brand counts for each unique ingredient
        next_combination_experiences = 64'd1;
        for (i = 0; i < 8; i = i + 1) begin
          if (next_ingredient_mask[i]) begin
            if (brands[i] == 4'd0) begin
              next_combination_experiences = 64'd0;
            end else begin
              // 64-bit multiply; truncation acceptable as threshold check follows
              next_combination_experiences = next_combination_experiences * brands[i];
            end
          end
        end

        // Accumulate and check threshold
        if (!too_many) begin
          if (next_total_experiences + next_combination_experiences >= THRESHOLD) begin
            next_total_experiences = THRESHOLD;
            next_too_many = 1'b1;
            next_state = DONE;
          end else begin
            next_total_experiences = next_total_experiences + next_combination_experiences;

            // Move to next combination
            if (d_idx + 1 < d) begin
              next_d_idx = d_idx + 1;
            end else begin
              next_d_idx = 3'd0;
              if (m_idx + 1 < m) begin
                next_m_idx = m_idx + 1;
              end else begin
                next_m_idx = 3'd0;
                if (s_idx + 1 < s) begin
                  next_s_idx = s_idx + 1;
                end else begin
                  next_state = DONE;
                end
              end
            end

            if (next_state != DONE)
              next_state = COMB_CHECK;
          end
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait until next start (handled in sequential logic)
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      s_idx <= 3'd0;
      m_idx <= 3'd0;
      d_idx <= 3'd0;
      total_experiences <= 64'd0;
      ingredient_mask <= 8'd0;
      combination_experiences <= 64'd0;
      too_many <= 1'b0;
      result <= 64'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      s_idx <= next_s_idx;
      m_idx <= next_m_idx;
      d_idx <= next_d_idx;
      total_experiences <= next_total_experiences;
      ingredient_mask <= next_ingredient_mask;
      combination_experiences <= next_combination_experiences;
      too_many <= next_too_many;

      if (state == IDLE && start) begin
        done <= 1'b0;
      end

      if (next_state == DONE) begin
        result <= too_many ? THRESHOLD : next_total_experiences;
        done <= 1'b1;
      end
    end
  end

endmodule