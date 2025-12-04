module course_optimizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] k,
  input [7:0][9:0] difficulties,
  input [7:0] is_level1,
  input [7:0] is_level2,
  input [7:0][2:0] pair_id,
  output reg [12:0] min_sum,
  output reg done
);

  typedef enum logic [1:0] {IDLE, CALCULATE, DONE_ST} state_t;
  state_t current_state, next_state;

  reg [3:0] cycle_counter;
  reg [3:0] n_reg;
  reg [3:0] k_reg;
  reg [7:0][9:0] difficulties_reg;
  reg [7:0] is_level1_reg;
  reg [7:0] is_level2_reg;
  reg [7:0][2:0] pair_id_reg;
  reg [12:0] stored_min_sum;

  logic [12:0] comb_min_sum;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cycle_counter <= 0;
      min_sum <= 0;
      done <= 0;
      stored_min_sum <= 13'h1FFF;
    end else begin
      current_state <= next_state;

      if (current_state == CALCULATE)
        cycle_counter <= cycle_counter + 1;
      else
        cycle_counter <= 0;

      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            n_reg <= n;
            k_reg <= k;
            difficulties_reg <= difficulties;
            is_level1_reg <= is_level1;
            is_level2_reg <= is_level2;
            pair_id_reg <= pair_id;
          end
        end
        CALCULATE: begin
          if (cycle_counter == 0)
            stored_min_sum <= comb_min_sum;
          if (cycle_counter == 15)
            done <= 1;
        end
        DONE_ST: begin
          done <= 0;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: next_state = (start) ? CALCULATE : IDLE;
      CALCULATE: next_state = (cycle_counter == 15) ? DONE_ST : CALCULATE;
      DONE_ST: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    comb_min_sum = 13'h1FFF;
    for (int mask = 0; mask < 256; mask++) begin
      logic [7:0] sel = mask;
      logic valid = 1'b1;
      logic [4:0] cnt = 0;
      logic [12:0] sum = 0;

      for (int i = 0; i < 8; i++) begin
        if (i < n_reg) begin
          if (sel[i]) begin
            cnt += 1;
            sum += difficulties_reg[i];

            if (is_level2_reg[i] && |pair_id_reg[i]) begin
              logic found_pair = 0;
              for (int j = 0; j < 8; j++) begin
                if (j != i && sel[j] && is_level1_reg[j] && (pair_id_reg[j] == pair_id_reg[i]))
                  found_pair = 1;
              end
              if (!found_pair)
                valid = 0;
            end
          end
        end
      end

      if (valid && (cnt == k_reg) && (sum < comb_min_sum))
        comb_min_sum = sum;
    end
  end

  always_ff @(posedge clk) begin
    if (current_state == CALCULATE && cycle_counter == 15)
      min_sum <= stored_min_sum;
  end

endmodule