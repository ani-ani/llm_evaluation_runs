module vote_optimizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] v,
  input [15:0] p_i [0:6],
  input [15:0] b_i [0:6],
  output reg [15:0] b_v,
  output reg done
);

  typedef enum {
    IDLE,
    INIT,
    LOOP_BV,
    LOOP_COMB,
    CALC_PROB,
    COMPUTE_WINS,
    ACCUMULATE,
    CHECK_COMB,
    CHECK_BV,
    FINISH
  } state_t;

  state_t state, next_state;
  reg [15:0] bv_counter;
  reg [6:0] comb_counter;
  reg [2:0] voter_idx;
  reg [15:0] current_bv;
  reg [31:0] current_exp;
  reg [31:0] max_expected_value;
  reg [15:0] best_bv_reg;
  reg [15:0] total_ballots;
  reg [31:0] product;
  reg [4:0] wins;
  reg [31:0] weighted_wins;
  wire [6:0] comb_max;
  wire all_comb_done;
  wire all_bv_done;
  
  function automatic [4:0] popcount(input [15:0] data);
    begin
      popcount = data[0] + data[1] + data[2] + data[3] + data[4] + data[5] +
                 data[6] + data[7] + data[8] + data[9] + data[10] + data[11] +
                 data[12] + data[13] + data[14] + data[15];
    end
  endfunction

  assign comb_max = (1 << (v - 1)) - 1;
  assign all_comb_done = (comb_counter == comb_max[6:0]);
  assign all_bv_done = (bv_counter == 16'hFFFF);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      bv_counter <= 0;
      comb_counter <= 0;
      current_exp <= 0;
      max_expected_value <= 0;
      best_bv_reg <= 0;
      current_bv <= 0;
      b_v <= 0;
    end else begin
      state <= next_state;
      case (state)
        INIT: begin
          done <= 0;
          bv_counter <= 0;
          comb_counter <= 0;
          current_exp <= 0;
          max_expected_value <= 0;
          best_bv_reg <= 0;
          current_bv <= 0;
        end
        LOOP_BV: begin
          if (next_state != LOOP_BV) current_bv <= bv_counter;
          current_exp <= 0;
        end
        LOOP_COMB: begin
          if (next_state != LOOP_COMB) voter_idx <= 0;
          comb_counter <= next_state == CHECK_COMB ? comb_counter + 1 : comb_counter;
        end
        CALC_PROB: begin
          voter_idx <= voter_idx + 1;
          product <= (voter_idx == 0) ? 32'h00010000 : 
                     product * (comb_counter[voter_idx-1] ? p_i[voter_idx-1] : (16'h0100 - p_i[voter_idx-1])) >> 8;
        end
        COMPUTE_WINS: begin
          wins <= popcount(total_ballots);
        end
        ACCUMULATE: begin
          current_exp <= current_exp + weighted_wins;
        end
        CHECK_BV: begin
          if (current_exp > max_expected_value) begin
            max_expected_value <= current_exp;
            best_bv_reg <= current_bv;
          end
          bv_counter <= bv_counter + 1;
        end
        FINISH: begin
          b_v <= best_bv_reg;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

  always_comb begin
    total_ballots = current_bv;
    for (int i = 0; i < 7; i = i + 1) begin
      if (i < v-1 && comb_counter[i]) total_ballots = total_ballots + b_i[i];
    end
    weighted_wins = product * wins;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = LOOP_BV;
      LOOP_BV: next_state = LOOP_COMB;
      LOOP_COMB: next_state = CALC_PROB;
      CALC_PROB: begin
        if (voter_idx < v-1) next_state = CALC_PROB;
        else next_state = COMPUTE_WINS;
      end
      COMPUTE_WINS: next_state = ACCUMULATE;
      ACCUMULATE: next_state = CHECK_COMB;
      CHECK_COMB: next_state = all_comb_done ? CHECK_BV : LOOP_COMB;
      CHECK_BV: next_state = all_bv_done ? FINISH : LOOP_BV;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule