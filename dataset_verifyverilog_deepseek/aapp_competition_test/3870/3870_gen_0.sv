module max_card_damage(
  input clk,
  input rst_n,
  input start,
  input [3:0] jiro_cnt,
  input [3:0][15:0] j_strength,
  input [3:0] j_type,
  input [3:0] ciel_cnt,
  input [3:0][15:0] c_strength,
  output reg [15:0] damage,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    SORT_JIRO,
    SORT_CIEL,
    CALC_STRAT1,
    CALC_STRAT2,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0][15:0] sorted_j_str, sorted_c_str;
  reg [3:0] sorted_j_type;
  reg [2:0] j_sort_idx, j_sort_i, c_sort_idx, c_sort_i;
  reg [3:0][15:0] def_str, atk_str;
  reg [2:0] def_cnt, atk_cnt;
  reg [15:0] strat1_damage, strat2_damage;
  reg [4:0] cycle_count;
  reg [3:0] temp_cnt;
  reg [7:0] usable_ciel;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      damage <= 0;
      cycle_count <= 0;
    end else begin
      current_state <= next_state;
      cycle_count <= (current_state != IDLE) ? cycle_count + 1 : 0;

      case (current_state)
        IDLE: begin
          done <= 0;
          damage <= 0;
          if (start) begin
            sorted_j_str <= j_strength;
            sorted_j_type <= j_type;
            sorted_c_str <= c_strength;
            j_sort_idx <= 0;
            j_sort_i <= 0;
            c_sort_idx <= 0;
            c_sort_i <= 0;
            next_state <= SORT_JIRO;
          end else next_state <= IDLE;
        end

        SORT_JIRO: begin
          if (j_sort_i < jiro_cnt - 1) begin
            if (j_sort_idx < jiro_cnt - j_sort_i - 1) begin
              if (sorted_j_str[j_sort_idx] > sorted_j_str[j_sort_idx+1]) begin
                sorted_j_str[j_sort_idx] <= sorted_j_str[j_sort_idx+1];
                sorted_j_str[j_sort_idx+1] <= sorted_j_str[j_sort_idx];
                sorted_j_type[j_sort_idx] <= sorted_j_type[j_sort_idx+1];
                sorted_j_type[j_sort_idx+1] <= sorted_j_type[j_sort_idx];
              end
              j_sort_idx <= j_sort_idx + 1;
            end else begin
              j_sort_idx <= 0;
              j_sort_i <= j_sort_i + 1;
            end
            next_state <= SORT_JIRO;
          end else begin
            temp_cnt <= 0;
            def_cnt <= 0;
            atk_cnt <= 0;
            next_state <= SORT_CIEL;
          end
        end

        SORT_CIEL: begin
          if (c_sort_i < ciel_cnt - 1) begin
            if (c_sort_idx < ciel_cnt - c_sort_i - 1) begin
              if (sorted_c_str[c_sort_idx] > sorted_c_str[c_sort_idx+1]) begin
                sorted_c_str[c_sort_idx] <= sorted_c_str[c_sort_idx+1];
                sorted_c_str[c_sort_idx+1] <= sorted_c_str[c_sort_idx];
              end
              c_sort_idx <= c_sort_idx + 1;
            end else begin
              c_sort_idx <= 0;
              c_sort_i <= c_sort_i + 1;
            end
            next_state <= SORT_CIEL;
          end else begin
            temp_cnt <= 0;
            def_cnt <= 0;
            atk_cnt <= 0;
            next_state <= CALC_STRAT1;
          end
        end

        CALC_STRAT1: begin
          if (temp_cnt < 4) begin
            if (sorted_j_type[temp_cnt] == 0 && def_cnt < jiro_cnt) begin
              def_str[def_cnt] <= sorted_j_str[temp_cnt];
              def_cnt <= def_cnt + 1;
            end else if (atk_cnt < jiro_cnt) begin
              atk_str[atk_cnt] <= sorted_j_str[temp_cnt];
              atk_cnt <= atk_cnt + 1;
            end
            temp_cnt <= temp_cnt + 1;
            next_state <= CALC_STRAT1;
          end else begin
            strat1_damage <= 0;
            usable_ciel <= (ciel_cnt >= def_cnt) ? def_cnt : 0;
            temp_cnt <= 0;
            next_state <= CALC_STRAT1_WAIT;
          end
        end

        CALC_STRAT1_WAIT: begin
          strat1_damage <= 0;
          if (usable_ciel == def_cnt) begin
            for (integer i = 0; i < def_cnt; i=i+1) begin
              if (sorted_c_str[i] < def_str[i]) usable_ciel <= 0;
            end
          end
          temp_cnt <= 0;
          next_state <= CALC_STRAT1_DAMAGE;
        end

        CALC_STRAT1_DAMAGE: begin
          if (usable_ciel == def_cnt && temp_cnt < atk_cnt && temp_cnt < (ciel_cnt - def_cnt)) begin
            if (sorted_c_str[ciel_cnt - 1 - temp_cnt] > atk_str[temp_cnt]) begin
              strat1_damage <= (strat1_damage + (sorted_c_str[ciel_cnt - 1 - temp_cnt] - atk_str[temp_cnt])) > 65535 ? 16'hFFFF : strat1_damage + (sorted_c_str[ciel_cnt - 1 - temp_cnt] - atk_str[temp_cnt]);
            end
            temp_cnt <= temp_cnt + 1;
            next_state <= CALC_STRAT1_DAMAGE;
          end else begin
            next_state <= CALC_STRAT2;
          end
        end

        CALC_STRAT2: begin
          strat2_damage <= 0;
          temp_cnt <= (atk_cnt < ciel_cnt) ? atk_cnt : ciel_cnt;
          next_state <= CALC_STRAT2_DAMAGE;
        end

        CALC_STRAT2_DAMAGE: begin
          if (temp_cnt > 0) begin
            temp_cnt <= temp_cnt - 1;
            if (sorted_c_str[ciel_cnt - temp_cnt] > atk_str[atk_cnt - temp_cnt]) begin
              strat2_damage <= (strat2_damage + (sorted_c_str[ciel_cnt - temp_cnt] - atk_str[atk_cnt - temp_cnt])) > 65535 ? 16'hFFFF : strat2_damage + (sorted_c_str[ciel_cnt - temp_cnt] - atk_str[atk_cnt - temp_cnt]);
            end
            next_state <= CALC_STRAT2_DAMAGE;
          end else begin
            damage <= (strat1_damage > strat2_damage) ? strat1_damage : strat2_damage;
            done <= (cycle_count >= 19);
            next_state <= DONE;
          end
        end

        DONE: begin
          if (start) begin
            done <= 1;
            next_state <= DONE;
          end else begin
            done <= 0;
            next_state <= IDLE;
          end
        end

        default: next_state <= IDLE;
      endcase
    end
  end
endmodule