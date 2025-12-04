module dinner_experiences(
  input clk,
  input rst_n,
  input start,
  input [2:0] r,
  input [2:0] s, m, d,
  input [1:0] n,
  input [1:0] brands [0:7],
  input [4:0] dish_ingredients [0:5][0:7],
  input [4:0] incompatible [0:1][0:1],
  output reg [63:0] result,
  output reg done
);

typedef enum logic [1:0] {IDLE, COMB_CHECK, BRAND_CALC, DONE} state_e;

reg [1:0] state, next_state;
reg [2:0] combo_counter;
reg [1:0] check_phase;
reg current_valid;
reg [7:0] current_ingredients;
reg [4:0] s_idx, m_idx, d_dix;
wire dish_valid = (s_idx < s) && (m_idx < m) && (d_dix < d);

// Extract dish ingredients from indices
function automatic [7:0] get_dish_ingredients(input [4:0] dish_idx);
  get_dish_ingredients = 0;
  for (int i=0; i<8; i++) begin
    if (dish_ingredients[dish_idx][i] < r)
      get_dish_ingredients |= 1'b1 << dish_ingredients[dish_idx][i];
  end
endfunction

// Incompatibility check
function automatic logic is_invalid(input [7:0] ingredients);
  for (int i=0; i<n; i++) begin
    logic [4:0] ing1 = incompatible[i][0];
    logic [4:0] ing2 = incompatible[i][1];
    if (ingredients[ing1] && ingredients[ing2]) return 1;
  end
  return 0;
endfunction

// Calculate brand product
function automatic logic [63:0] calculate_product(input [7:0] ingredients);
  calculate_product = 1;
  for (int i=0; i<8; i++) begin
    if (ingredients[i]) begin
      calculate_product = calculate_product * brands[i];
      if (calculate_product > 64'd1000000000000000000) break;
    end
  end
endfunction

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    result <= 0;
    done <= 0;
    combo_counter <= 0;
    check_phase <= 0;
    current_ingredients <= 0;
    s_idx <= 0;
    m_idx <= 0;
    d_dix <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) begin
          state <= COMB_CHECK;
          combo_counter <= 0;
          result <= 0;
        end
      end

      COMB_CHECK: begin
        case (check_phase)
          0: begin // Set dish indices
            s_idx <= combo_counter[2];
            m_idx <= combo_counter[1];
            d_dix <= combo_counter[0];
            check_phase <= 1;
          end

          1: begin // Check validity
            if (dish_valid) begin
              logic [7:0] starter = get_dish_ingredients(s_idx);
              logic [7:0] main = get_dish_ingredients(m_idx + 2);
              logic [7:0] dessert = get_dish_ingredients(d_dix + 4);
              current_ingredients <= starter | main | dessert;
              current_valid <= !is_invalid(starter | main | dessert);
            end else begin
              current_valid <= 0;
            end
            state <= BRAND_CALC;
          end
        endcase
      end

      BRAND_CALC: begin
        if (current_valid && (result <= 64'd1000000000000000000)) begin
          logic [63:0] prod = calculate_product(current_ingredients);
          if (prod >= (64'd1000000000000000000 - result)) begin
            result <= 64'd1000000000000000000;
          end else begin
            result <= result + prod;
          end
        end

        if (combo_counter == 3'd7 || result == 64'd1000000000000000000) begin
          state <= DONE;
        end else begin
          combo_counter <= combo_counter + 1;
          state <= COMB_CHECK;
          check_phase <= 0;
        end
      end

      DONE: begin
        done <= 1;
        if (!start) state <= IDLE;
      end
    endcase
  end
end

endmodule