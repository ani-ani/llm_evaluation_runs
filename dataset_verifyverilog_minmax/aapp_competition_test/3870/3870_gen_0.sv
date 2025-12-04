module max_card_damage(
  input clk,          // Clock
  input rst_n,        // Active-low reset
  input start,        // Start computation
  // Jiro's cards (4 max):
  input [3:0] jiro_cnt,      // Number of Jiro cards (0-4)
  input [3:0][15:0] j_strength, // Card strengths
  input [3:0] j_type,         // 0=DEF, 1=ATK
  // Ciel's cards (4 max):
  input [3:0] ciel_cnt,      // Number of Ciel cards (0-4)
  input [3:0][15:0] c_strength, // Attack strengths
  // Output:
  output reg [15:0] damage,  // Max damage result
  output reg done            // Computation done
);

  // FSM states
  localparam IDLE = 3'd0;
  localparam SORT_JIRO = 3'd1;
  localparam SORT_CIEL = 3'd2;
  localparam CALC_STRAT1 = 3'd3;
  localparam CALC_STRAT2 = 3'd4;
  localparam DONE = 3'd5;

  // Internal storage for sorted data
  reg [3:0][15:0] j_sorted_strength;
  reg [3:0] j_sorted_type;
  reg [3:0][15:0] c_sorted_strength;
  
  // State registers
  reg [2:0] state, next_state;
  
  // Bubble sort control
  reg [3:0] sort_i, sort_j; // indices for bubble sort
  reg [3:0] comparisons_done; // count of comparisons completed
  
  // Damage calculation results
  reg [15:0] damage1, damage2;
  
  // Function to calculate damage for strategy 1
  function [15:0] calc_strat1;
    input [3:0] j_cnt;
    input [3:0][15:0] j_strength;
    input [3:0] j_type;
    input [3:0] ciel_cnt;
    input [3:0][15:0] ciel_strength;
    
    integer i, j, k;
    integer ciel_index;
    reg [15:0] damage;
    reg found;
    
    begin
      damage = 0;
      ciel_index = 0;
      
      // Destroy DEF cards first
      for (i = 0; i < j_cnt; i = i + 1) begin
        if (j_type[i] == 0) begin // DEF card
          found = 1'b0;
          for (j = ciel_index; j < ciel_cnt; j = j + 1) begin
            if (ciel_strength[j] >= j_strength[i]) begin
              ciel_index = j + 1;
              found = 1'b1;
              break;
            end
          end
        end
      end
      
      // Then attack ATK cards
      for (i = 0; i < j_cnt; i = i + 1) begin
        if (j_type[i] == 1) begin // ATK card
          found = 1'b0;
          for (j = ciel_index; j < ciel_cnt; j = j + 1) begin
            if (ciel_strength[j] >= j_strength[i]) begin
              ciel_index = j + 1;
              found = 1'b1;
              break;
            end
          end
          if (!found) begin
            damage = damage + j_strength[i];
            if (damage > 16'hFFFF) damage = 16'hFFFF; // Saturation
          end
        end
      end
      
      calc_strat1 = damage;
    end
  endfunction
  
  // Function to calculate damage for strategy 2
  function [15:0] calc_strat2;
    input [3:0] j_cnt;
    input [3:0][15:0] j_strength;
    input [3:0] j_type;
    input [3:0] ciel_cnt;
    input [3:0][15:0] ciel_strength;
    
    integer i, j;
    integer i_c;
    reg [15:0] damage;
    reg found;
    
    // Extract ATK cards
    reg [3:0][15:0] atk_cards;
    integer atk_count;
    
    begin
      // Extract ATK cards
      atk_count = 0;
      for (i = 0; i < j_cnt; i = i + 1) begin
        if (j_type[i] == 1) begin // ATK card
          atk_cards[atk_count] = j_strength[i];
          atk_count = atk_count + 1;
        end
      end
      
      // Attack ATK cards from strongest to weakest
      damage = 0;
      i_c = ciel_cnt - 1; // Start from strongest Ciel card
      
      for (i = atk_count - 1; i >= 0; i = i - 1) begin
        found = 1'b0;
        for (j = i_c; j >= 0; j = j - 1) begin
          if (ciel_strength[j] >= atk_cards[i]) begin
            i_c = j - 1;
            found = 1'b1;
            break;
          end
        end
        if (!found) begin
          damage = damage + atk_cards[i];
          if (damage > 16'hFFFF) damage = 16'hFFFF; // Saturation
        end
      end
      
      calc_strat2 = damage;
    end
  endfunction
  
  // Main FSM state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      damage <= 16'd0;
    end else begin
      state <= next_state;
      done <= 1'b0;
    end
  end
  
  // Next state logic
  always_comb begin
    next_state = state;
    
    case (state)
      IDLE: begin
        if (start) begin
          next_state = SORT_JIRO;
        end
      end
      
      SORT_JIRO: begin
        if (jiro_cnt <= 1) begin
          // No need to sort
          next_state = SORT_CIEL;
        end else if (comparisons_done >= (jiro_cnt * (jiro_cnt - 1)) / 2) begin
          // Sort complete
          next_state = SORT_CIEL;
        end
        // Else stay in SORT_JIRO and do next comparison
      end
      
      SORT_CIEL: begin
        if (ciel_cnt <= 1) begin
          next_state = CALC_STRAT1;
        end else if (comparisons_done >= (ciel_cnt * (ciel_cnt - 1)) / 2) begin
          next_state = CALC_STRAT1;
        end
      end
      
      CALC_STRAT1: begin
        next_state = CALC_STRAT2;
      end
      
      CALC_STRAT2: begin
        next_state = DONE;
      end
      
      DONE: begin
        done <= 1'b1;
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end
  
  // Bubble sort implementation
  always_ff @(posedge clk) begin
    if (state == SORT_JIRO) begin
      if (jiro_cnt > 1) begin
        if (sort_i < jiro_cnt - 1) begin
          if (j_sorted_strength[sort_i] > j_sorted_strength[sort_i + 1]) begin
            // Swap
            j_sorted_strength[sort_i] <= j_sorted_strength[sort_i + 1];
            j_sorted_strength[sort_i + 1] <= j_sorted_strength[sort_i];
            j_sorted_type[sort_i] <= j_sorted_type[sort_i + 1];
            j_sorted_type[sort_i + 1] <= j_sorted_type[sort_i];
          end
          sort_i <= sort_i + 1;
        end else begin
          sort_i <= 4'd0;
          comparisons_done <= comparisons_done + 1;
        end
      end else begin
        comparisons_done <= 4'd1; // Mark as done
      end
    end else if (state == SORT_CIEL) begin
      if (ciel_cnt > 1) begin
        if (sort_i < ciel_cnt - 1) begin
          if (c_sorted_strength[sort_i] > c_sorted_strength[sort_i + 1]) begin
            // Swap
            c_sorted_strength[sort_i] <= c_sorted_strength[sort_i + 1];
            c_sorted_strength[sort_i + 1] <= c_sorted_strength[sort_i];
          end
          sort_i <= sort_i + 1;
        end else begin
          sort_i <= 4'd0;
          comparisons_done <= comparisons_done + 1;
        end
      end else begin
        comparisons_done <= 4'd1; // Mark as done
      end
    end else begin
      // Reset sort control on state change
      sort_i <= 4'd0;
      comparisons_done <= 4'd0;
    end
  end
  
  // Initialize sorted arrays when entering sort states
  always_ff @(posedge clk) begin
    if (state == SORT_JIRO) begin
      // Load current Jiro cards into sorted array
      j_sorted_strength[0] <= j_strength[0];
      j_sorted_strength[1] <= j_strength[1];
      j_sorted_strength[2] <= j_strength[2];
      j_sorted_strength[3] <= j_strength[3];
      j_sorted_type[0] <= j_type[0];
      j_sorted_type[1] <= j_type[1];
      j_sorted_type[2] <= j_type[2];
      j_sorted_type[3] <= j_type[3];
    end else if (state == SORT_CIEL) begin
      // Load current Ciel cards into sorted array
      c_sorted_strength[0] <= c_strength[0];
      c_sorted_strength[1] <= c_strength[1];
      c_sorted_strength[2] <= c_strength[2];
      c_sorted_strength[3] <= c_strength[3];
    end
  end
  
  // Damage calculation
  always_ff @(posedge clk) begin
    if (state == CALC_STRAT1) begin
      damage1 <= calc_strat1(jiro_cnt, j_sorted_strength, j_sorted_type, 
                           ciel_cnt, c_sorted_strength);
    end else if (state == CALC_STRAT2) begin
      damage2 <= calc_strat2(jiro_cnt, j_sorted_strength, j_sorted_type, 
                           ciel_cnt, c_sorted_strength);
    end else if (state == DONE) begin
      damage <= (damage1 > damage2) ? damage1 : damage2;
    end
  end
  
endmodule