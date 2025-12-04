module team_selector(
  input clk, // Clock input
  input rst_n, // Active-low reset
  input start, // Start computation
  input [7:0] a [0:7], // Programming skills (8 students)
  input [7:0] b [0:7], // Sports skills (8 students)
  output reg [10:0] max_strength, // Maximum total strength (11-bit)
  output reg [7:0] prog_team, // 1-hot encoded programming team
  output reg [7:0] sport_team, // 1-hot encoded sports team
  output reg done // High when computation complete
);

  // State machine states
  typedef enum {IDLE, CALC, OUTPUT} state_t;
  state_t state, next_state;
  
  // Calculation sub-state counter
  reg [1:0] calc_state, next_calc_state;
  
  // Student pair indices for precomputation
  parameter [5:0] PAIR [0:27][1:0] = '{
    {0,1}, {0,2}, {0,3}, {0,4}, {0,5}, {0,6}, {0,7},
    {1,2}, {1,3}, {1,4}, {1,5}, {1,6}, {1,7},
    {2,3}, {2,4}, {2,5}, {2,6}, {2,7},
    {3,4}, {3,5}, {3,6}, {3,7},
    {4,5}, {4,6}, {4,7},
    {5,6}, {5,7},
    {6,7}
  };
  
  // Registers for programming and sports pairs
  reg [5:0] prog_pair_student1 [0:27];
  reg [5:0] prog_pair_student2 [0:27];
  reg [7:0] prog_pair_sum [0:27];
  reg [5:0] sport_pair_student1 [0:27];
  reg [5:0] sport_pair_student2 [0:27];
  reg [7:0] sport_pair_sum [0:27];
  
  // Best sports pair for each programming pair (combinational)
  reg [7:0] best_sports_sum_comb [0:27];
  reg [5:0] best_sport_index_comb [0:27];
  
  // Best sports pair for each programming pair (registered)
  reg [7:0] best_sports_sum [0:27];
  reg [5:0] best_sport_index [0:27];
  
  // Final best indices and strength
  reg [5:0] best_prog_index, best_sport_index;
  reg [10:0] max_strength_reg;
  
  // Disjoint function
  function [0:0] disjoint;
    input [5:0] i1, i2, j1, j2;
    begin
      disjoint = (i1 != j1) && (i1 != j2) && (i2 != j1) && (i2 != j2);
    end
  endfunction
  
  // Combinational logic for best sports pair selection
  always_comb begin
    if (calc_state == 2) begin
      for (int i = 0; i < 28; i++) begin
        best_sports_sum_comb[i] = 0;
        best_sport_index_comb[i] = 0;
        for (int j = 0; j < 28; j++) begin
          if (disjoint(prog_pair_student1[i], prog_pair_student2[i], 
                       sport_pair_student1[j], sport_pair_student2[j])) begin
            if (sport_pair_sum[j] > best_sports_sum_comb[i]) begin
              best_sports_sum_comb[i] = sport_pair_sum[j];
              best_sport_index_comb[i] = j;
            end
          end
        end
      end
    end else begin
      for (int i = 0; i < 28; i++) begin
        best_sports_sum_comb[i] = 0;
        best_sport_index_comb[i] = 0;
      end
    end
  end
  
  // State machine logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      calc_state <= 0;
      max_strength <= 0;
      prog_team <= 0;
      sport_team <= 0;
      done <= 0;
    end else begin
      // Update state and counters
      state <= next_state;
      calc_state <= next_calc_state;
      
      // Update pair registers based on current state
      if (calc_state == 0) begin
        for (int k = 0; k < 28; k++) begin
          prog_pair_student1[k] <= PAIR[k][0];
          prog_pair_student2[k] <= PAIR[k][1];
          prog_pair_sum[k] <= a[PAIR[k][0]] + a[PAIR[k][1]];
        end
      end else if (calc_state == 1) begin
        for (int k = 0; k < 28; k++) begin
          sport_pair_student1[k] <= PAIR[k][0];
          sport_pair_student2[k] <= PAIR[k][1];
          sport_pair_sum[k] <= b[PAIR[k][0]] + b[PAIR[k][1]];
        end
      end else if (calc_state == 2) begin
        for (int i = 0; i < 28; i++) begin
          best_sports_sum[i] <= best_sports_sum_comb[i];
          best_sport_index[i] <= best_sport_index_comb[i];
        end
      end else if (calc_state == 3) begin
        max_strength_reg <= max_strength_reg;
        best_prog_index <= best_prog_index;
        best_sport_index <= best_sport_index;
      end
      
      // Update outputs in OUTPUT state
      if (next_state == OUTPUT) begin
        max_strength <= max_strength_reg;
        prog_team <= (1 << prog_pair_student1[best_prog_index]) | (1 << prog_pair_student2[best_prog_index]);
        sport_team <= (1 << sport_pair_student1[best_sport_index]) | (1 << sport_pair_student2[best_sport_index]);
        done <= 1;
      end else if (state != OUTPUT) begin
        max_strength <= 0;
        prog_team <= 0;
        sport_team <= 0;
        done <= 0;
      end
    end
  end
  
  // Next state logic
  always_comb begin
    next_state = state;
    next_calc_state = calc_state;
    
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC;
          next_calc_state = 0;
        end
      end
      CALC: begin
        case (calc_state)
          0: next_calc_state = 1;
          1: next_calc_state = 2;
          2: begin
            next_calc_state = 3;
            // Initialize best values
            max_strength_reg = 0;
            best_prog_index = 0;
            best_sport_index = 0;
            for (int i = 0; i < 28; i++) begin
              if ((prog_pair_sum[i] + best_sports_sum[i]) > max_strength_reg) begin
                max_strength_reg = prog_pair_sum[i] + best_sports_sum[i];
                best_prog_index = i;
                best_sport_index = best_sport_index[i];
              end
            end
          end
          3: next_state = OUTPUT;
        endcase
      end
      OUTPUT: next_state = IDLE;
    endcase
  end
endmodule