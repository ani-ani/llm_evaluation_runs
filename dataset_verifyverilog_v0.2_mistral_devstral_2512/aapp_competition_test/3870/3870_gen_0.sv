module card_game_solver #(
  parameter N_ATK = 2,
  parameter N_DEF = 2,
  parameter M = 8
)(
  input clk,
  input rst_n,
  input start,
  input [N_ATK-1:0] jatk_en,
  input [N_ATK-1:0][7:0] jatk_str,
  input [N_DEF-1:0] jdef_en,
  input [N_DEF-1:0][7:0] jdef_str,
  input [M-1:0][7:0] ciel_str,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [4:0] {
    IDLE,
    LOAD,
    SORT,
    STRATEGY1_CHECK,
    STRATEGY1_MATCH_DEF,
    STRATEGY1_MATCH_ATK,
    STRATEGY1_DIRECT,
    STRATEGY2_MATCH,
    STORE_RESULT,
    DONE
  } state_t;

  state_t state;

  // Internal registers
  reg [N_ATK-1:0] jatk_en_reg;
  reg [N_ATK-1:0][7:0] jatk_str_reg;
  reg [N_DEF-1:0] jdef_en_reg;
  reg [N_DEF-1:0][7:0] jdef_str_reg;
  reg [M-1:0][7:0] ciel_str_reg;
  reg [M-1:0][7:0] ciel_sorted;

  reg [15:0] strategy1_result;
  reg [15:0] strategy2_result;

  // Sorting variables
  reg [3:0] sort_i;
  reg [3:0] sort_j;
  reg [3:0] sort_k;

  // Strategy 1 variables
  reg [1:0] def_ptr;
  reg [2:0] ciel_ptr;
  reg [15:0] total_damage;
  reg [15:0] used_damage;
  reg def_all_destroyed;
  reg atk_all_destroyed;

  // Strategy 2 variables
  reg [1:0] atk_ptr_s2;
  reg [2:0] ciel_ptr_s2;
  reg [15:0] s2_damage;

  // Counters
  reg [7:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            cycle_count <= 0;
          end
        end

        LOAD: begin
          // Load all inputs
          jatk_en_reg <= jatk_en;
          jatk_str_reg <= jatk_str;
          jdef_en_reg <= jdef_en;
          jdef_str_reg <= jdef_str;
          ciel_str_reg <= ciel_str;
          ciel_sorted <= ciel_str;
          state <= SORT;
          sort_i <= 0;
          sort_j <= 0;
          sort_k <= 0;
        end

        SORT: begin
          // Bubble sort implementation
          if (sort_i < M-1) begin
            if (sort_j < M-sort_i-1) begin
              if (ciel_sorted[sort_j] > ciel_sorted[sort_j+1]) begin
                // Swap
                ciel_sorted[sort_j] <= ciel_sorted[sort_j+1];
                ciel_sorted[sort_j+1] <= ciel_sorted[sort_j];
              end
              sort_j <= sort_j + 1;
            end else begin
              sort_j <= 0;
              sort_i <= sort_i + 1;
            end
          end else begin
            state <= STRATEGY1_CHECK;
            def_ptr <= 0;
            ciel_ptr <= 0;
            total_damage <= 0;
            used_damage <= 0;
            def_all_destroyed <= 1;
            atk_all_destroyed <= 1;
          end
          cycle_count <= cycle_count + 1;
        end

        STRATEGY1_CHECK: begin
          // Check if all DEF cards are destroyed
          if (def_ptr < N_DEF) begin
            if (jdef_en_reg[def_ptr]) begin
              def_all_destroyed <= 0;
              state <= STRATEGY1_MATCH_DEF;
            end else begin
              def_ptr <= def_ptr + 1;
            end
          end else begin
            state <= STRATEGY1_MATCH_ATK;
            atk_ptr <= 0;
          end
        end

        STRATEGY1_MATCH_DEF: begin
          // Find smallest Ciel card > DEF strength
          if (ciel_ptr < M) begin
            if (ciel_sorted[ciel_ptr] > jdef_str_reg[def_ptr]) begin
              used_damage <= used_damage + ciel_sorted[ciel_ptr];
              ciel_ptr <= ciel_ptr + 1;
              def_ptr <= def_ptr + 1;
              state <= STRATEGY1_CHECK;
            end else begin
              ciel_ptr <= ciel_ptr + 1;
            end
          end else begin
            // No card found to destroy this DEF
            def_all_destroyed <= 0;
            state <= STRATEGY1_MATCH_ATK;
            atk_ptr <= 0;
          end
        end

        STRATEGY1_MATCH_ATK: begin
          // Match smallest ATK cards with smallest Ciel cards >= ATK strength
          if (atk_ptr < N_ATK) begin
            if (jatk_en_reg[atk_ptr]) begin
              if (ciel_ptr < M) begin
                if (ciel_sorted[ciel_ptr] >= jatk_str_reg[atk_ptr]) begin
                  used_damage <= used_damage + ciel_sorted[ciel_ptr];
                  ciel_ptr <= ciel_ptr + 1;
                  atk_ptr <= atk_ptr + 1;
                end else begin
                  ciel_ptr <= ciel_ptr + 1;
                end
              end else begin
                atk_all_destroyed <= 0;
                atk_ptr <= atk_ptr + 1;
              end
            end else begin
              atk_ptr <= atk_ptr + 1;
            end
          end else begin
            // Calculate total damage
            for (int i = 0; i < M; i = i + 1) begin
              total_damage <= total_damage + ciel_sorted[i];
            end
            if (def_all_destroyed && atk_all_destroyed) begin
              strategy1_result <= total_damage - used_damage;
            end else begin
              strategy1_result <= 0;
            end
            state <= STRATEGY2_MATCH;
            atk_ptr_s2 <= 0;
            ciel_ptr_s2 <= M-1;
            s2_damage <= 0;
          end
        end

        STRATEGY2_MATCH: begin
          // Match largest Ciel cards with smallest ATK cards
          if (atk_ptr_s2 < N_ATK && ciel_ptr_s2 >= 0) begin
            if (jatk_en_reg[atk_ptr_s2]) begin
              if (ciel_sorted[ciel_ptr_s2] >= jatk_str_reg[atk_ptr_s2]) begin
                s2_damage <= s2_damage + (ciel_sorted[ciel_ptr_s2] - jatk_str_reg[atk_ptr_s2]);
                ciel_ptr_s2 <= ciel_ptr_s2 - 1;
                atk_ptr_s2 <= atk_ptr_s2 + 1;
              end else begin
                atk_ptr_s2 <= atk_ptr_s2 + 1;
              end
            end else begin
              atk_ptr_s2 <= atk_ptr_s2 + 1;
            end
          end else begin
            strategy2_result <= s2_damage;
            state <= STORE_RESULT;
          end
        end

        STORE_RESULT: begin
          if (strategy1_result > strategy2_result) begin
            result <= strategy1_result;
          end else begin
            result <= strategy2_result;
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Default assignments
  reg [1:0] atk_ptr;
  always @* begin
    atk_ptr = 0;
  end

endmodule