module min_uw_distance(
  input clk,
  input rst_n,
  input start,
  input [7:0] gravity [0:7],
  input [7:0] system_type,
  input [7:0][7:0] adjacency_matrix,
  output reg [23:0] min_distance,
  output reg done
);

  typedef enum logic [2:0] {IDLE, ADJUST, COMP_SQ, COMP_CUBE, ITER_PAIRS, FINISH} state_t;
  state_t state_reg, state_next;
  reg [3:0] option_reg, option_next;
  reg [2:0] human_counter_reg, human_counter_next;
  reg [2:0] alien_counter_reg, alien_counter_next;
  reg [23:0] min_distance_reg, min_distance_next;
  reg [23:0] cycle_counter_reg, cycle_counter_next;
  reg [15:0] square_reg [0:7];
  reg [23:0] cube_array_reg [0:7];
  reg [7:0] gravity_adj_reg [0:7];
  reg [7:0] human_count_reg, alien_count_reg;
  reg [23:0] total_cycles_reg;
  reg done_reg;
  wire [23:0] uw_distance;

  always_comb begin
    human_count_reg = 0;
    alien_count_reg = 0;
    for (int i=0; i<8; i++) begin
      if (system_type[i] == 1'b0) human_count_reg += 1;
      else alien_count_reg += 1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      option_reg <= 0;
      human_counter_reg <= 0;
      alien_counter_reg <= 0;
      min_distance_reg <= 24'hFFFFFF;
      cycle_counter_reg <= 0;
      done <= 0;
    end else begin
      state_reg <= state_next;
      option_reg <= option_next;
      human_counter_reg <= human_counter_next;
      alien_counter_reg <= alien_counter_next;
      min_distance_reg <= min_distance_next;
      cycle_counter_reg <= cycle_counter_next;
      done <= (state_reg == FINISH) || (cycle_counter_reg >= total_cycles_reg);
    end
  end

  always_comb begin
    state_next = state_reg;
    option_next = option_reg;
    human_counter_next = human_counter_reg;
    alien_counter_next = alien_counter_reg;
    min_distance_next = min_distance_reg;
    cycle_counter_next = cycle_counter_reg;
    
    for (int i=0; i<8; i++) begin
      gravity_adj_reg[i] = gravity[i];
      square_reg[i] = gravity_adj_reg[i] * gravity_adj_reg[i];
      cube_array_reg[i] = square_reg[i] * gravity_adj_reg[i];
    end
    
    case (state_reg)
      IDLE: begin
        if (start) begin
          total_cycles_reg = 9 * human_count_reg * alien_count_reg + 20;
          state_next = ADJUST;
          option_next = 0;
          min_distance_next = 24'hFFFFFF;
          cycle_counter_next = 0;
        end
        
        for (int i=0; i<8; i++) begin
          gravity_adj_reg[i] = gravity[i];
        end
      end
      
      ADJUST: begin
        if (option_reg != 0) begin
          integer node = option_reg - 1;
          for (int i=0; i<8; i++) begin
            if (i == node) gravity_adj_reg[i] -= 1;
            if (adjacency_matrix[node][i]) gravity_adj_reg[i] += 1;
          end
        end
        state_next = COMP_SQ;
      end
      
      COMP_SQ: state_next = COMP_CUBE;
      
      COMP_CUBE: begin
        human_counter_next = 0;
        alien_counter_next = 0;
        state_next = ITER_PAIRS;
      end
      
      ITER_PAIRS: begin
        if (human_counter_reg < 8 && alien_counter_reg < 8) begin
          if (system_type[human_counter_reg] === 1'b0 && system_type[alien_counter_reg] === 1'b1) begin
            uw_distance = (cube_array_reg[alien_counter_reg] >= cube_array_reg[human_counter_reg]) ? 
              (cube_array_reg[alien_counter_reg] - cube_array_reg[human_counter_reg]) : 
              (cube_array_reg[human_counter_reg] - cube_array_reg[alien_counter_reg]);
            if (uw_distance < min_distance_reg)
              min_distance_next = uw_distance;
          end
          
          if (alien_counter_reg == 7) begin
            alien_counter_next = 0;
            human_counter_next = human_counter_reg + 1;
          end else begin
            alien_counter_next = alien_counter_reg + 1;
          end
        end else begin
          if (option_reg == 8)
            state_next = FINISH;
          else begin
            option_next = option_reg + 1;
            state_next = ADJUST;
          end
        end
      end
      
      FINISH: state_next = IDLE;
      
      default: state_next = IDLE;
    endcase
  end
  
  assign min_distance = min_distance_reg;

endmodule