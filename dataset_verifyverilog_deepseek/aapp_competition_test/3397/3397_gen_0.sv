module dog_feeding_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [7:0] eating_times_0_0, eating_times_0_1, eating_times_0_2, eating_times_0_3, eating_times_0_4, eating_times_0_5,
  input [7:0] eating_times_1_0, eating_times_1_1, eating_times_1_2, eating_times_1_3, eating_times_1_4, eating_times_1_5,
  input [7:0] eating_times_2_0, eating_times_2_1, eating_times_2_2, eating_times_2_3, eating_times_2_4, eating_times_2_5,
  input [7:0] eating_times_3_0, eating_times_3_1, eating_times_3_2, eating_times_3_3, eating_times_3_4, eating_times_3_5,
  output reg [9:0] result,
  output reg done
);

  typedef enum {
    IDLE,
    INIT,
    INCR,
    CHECK_PERM,
    GET_EAT_TIMES,
    FIND_MAX,
    CALC_T,
    COMPARE,
    DONE_ST
  } state_t;

  state_t current_state, next_state;
  reg [2:0] bowl_sel [0:3];  // 4 dogs x 3b
  reg [2:0] fixed_n_reg;
  reg [2:0] fixed_m_reg;
  reg [5:0] occupied;
  reg incr_done, all_incremented;
  reg [3:0] idx;
  reg [9:0] min_T;
  reg [7:0] max_time;
  reg [7:0] eat_time[0:3];
  reg [9:0] T_total;
  reg [1:0] count;
  reg [3:0] dog_count;

  // Eating time muxes
  always_comb begin
    case (bowl_sel[0])
      3'd0: eat_time[0] = eating_times_0_0;
      3'd1: eat_time[0] = eating_times_0_1;
      3'd2: eat_time[0] = eating_times_0_2;
      3'd3: eat_time[0] = eating_times_0_3;
      3'd4: eat_time[0] = eating_times_0_4;
      3'd5: eat_time[0] = eating_times_0_5;
      default: eat_time[0] = 8'b0;
    endcase
    case (bowl_sel[1])
      3'd0: eat_time[1] = eating_times_1_0;
      3'd1: eat_time[1] = eating_times_1_1;
      3'd2: eat_time[1] = eating_times_1_2;
      3'd3: eat_time[1] = eating_times_1_3;
      3'd4: eat_time[1] = eating_times_1_4;
      3'd5: eat_time[1] = eating_times_1_5;
      default: eat_time[1] = 8'b0;
    endcase
    case (bowl_sel[2])
      3'd0: eat_time[2] = eating_times_2_0;
      3'd1: eat_time[2] = eating_times_2_1;
      3'd2: eat_time[2] = eating_times_2_2;
      3'd3: eat_time[2] = eating_times_2_3;
      3'd4: eat_time[2] = eating_times_2_4;
      3'd5: eat_time[2] = eating_times_2_5;
      default: eat_time[2] = 8'b0;
    endcase
    case (bowl_sel[3])
      3'd0: eat_time[3] = eating_times_3_0;
      3'd1: eat_time[3] = eating_times_3_1;
      3'd2: eat_time[3] = eating_times_3_2;
      3'd3: eat_time[3] = eating_times_3_3;
      3'd4: eat_time[3] = eating_times_3_4;
      3'd5: eat_time[3] = eating_times_3_5;
      default: eat_time[3] = 8'b0;
    endcase
  end

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Main FSM
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: next_state = CHECK_PERM;
      CHECK_PERM: begin
        if (!incr_done) next_state = INCR;
        else if (all_incremented) next_state = DONE_ST;
        else if (|occupied[5:0] && (bowl_sel[idx] < fixed_m_reg) && (bowl_sel[0] != bowl_sel[1]) && (bowl_sel[0] != bowl_sel[2]) && (bowl_sel[0] != bowl_sel[3]) && (bowl_sel[1] != bowl_sel[2]) && (bowl_sel[1] != bowl_sel[3]) && (bowl_sel[2] != bowl_sel[3])) next_state = GET_EAT_TIMES;
        else next_state = INCR;
      end
      INCR: begin
        next_state = CHECK_PERM;
      end
      GET_EAT_TIMES: next_state = FIND_MAX;
      FIND_MAX: next_state = CALC_T;
      CALC_T: next_state = COMPARE;
      COMPARE: next_state = INCR;
      DONE_ST: next_state = IDLE;
    endcase
  end

  // Combinational and registered logic for each state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bowl_sel[0] <= 3'b0;
      bowl_sel[1] <= 3'b0;
      bowl_sel[2] <= 3'b0;
      bowl_sel[3] <= 3'b0;
      fixed_n_reg <= 3'b0;
      fixed_m_reg <= 3'b0;
      occupied <= 6'b0;
      incr_done <= 1'b0;
      all_incremented <= 1'b0;
      idx <= 4'd3;
      min_T <= 10'h3FF;
      max_time <= 8'b0;
      T_total <= 10'b0;
      count <= 2'b0;
      dog_count <= 4'b0;
      done <= 1'b0;
      result <= 10'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            fixed_n_reg <= n;
            fixed_m_reg <= m;
          end
        end
        INIT: begin
          bowl_sel[0] <= 3'b0;
          bowl_sel[1] <= 3'b001;
          bowl_sel[2] <= 3'b010;
          bowl_sel[3] <= 3'b011;
          occupied <= 6'b0;
          incr_done <= 1'b0;
          all_incremented <= 1'b0;
          idx <= 4'd3;
          min_T <= 10'h3FF;
          dog_count <= 4'b0;
          count <= 2'b0;
          T_total <= 10'b0;
        end
        INCR: begin
          if (idx == 0 && bowl_sel[idx] == fixed_m_reg -1) begin
            all_incremented <= 1'b1;
          end else if (bowl_sel[idx] == fixed_m_reg - 1) begin
            bowl_sel[idx] <= 3'b0;
            idx <= idx - 1;
          end else begin
            bowl_sel[idx] <= bowl_sel[idx] + 1'b1;
            if (idx < fixed_n_reg -1) begin
              idx <= fixed_n_reg - 1;
            end
          end
          if (idx == 0 && bowl_sel[idx] == fixed_m_reg -1) begin
            incr_done <= 1'b1;
          end else begin
            incr_done <= 1'b0;
          end
        end
        CHECK_PERM: begin
          // Auto-transition handled by FSM
        end
        GET_EAT_TIMES: begin
          // Auto-transition, values muxed comb
          dog_count <= 4'b0;
          max_time <= 8'b0;
          T_total <= 10'b0;
          count <= 2'b0;
        end
        FIND_MAX: begin
          if (count < fixed_n_reg) begin
            if (eat_time[count] > max_time) begin
              max_time <= eat_time[count];
            end
            count <= count + 1'b1;
          end else begin
            count <= 2'b0;
          end
        end
        CALC_T: begin
          if (dog_count < fixed_n_reg) begin
            if (dog_count == fixed_n_reg -1) begin
              T_total <= T_total + max_time - eat_time[dog_count];
            end else begin
              T_total <= T_total + max_time - eat_time[dog_count];
            end
            dog_count <= dog_count + 1'b1;
          end
        end
        COMPARE: begin
          if (T_total < min_T) begin
            min_T <= T_total;
          end
        end
        DONE_ST: begin
          result <= min_T;
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule