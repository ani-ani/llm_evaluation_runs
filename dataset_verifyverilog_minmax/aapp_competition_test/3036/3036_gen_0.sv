module dinner_experiences(
  input clk,                      // clock signal
  input rst_n,                    // active-low reset
  input start,                    // assert high to start computation
  input [2:0] r,                  // number of ingredients (max 8)
  input [2:0] s, m, d,           // courses: starters/mains/desserts (max 2)
  input [1:0] n,                  // incompatible pairs (max 2)
  input [1:0] brands [0:7],       // brand counts per ingredient (4-bit values)
  input [4:0] dish_ingredients [0:5][0:7], // [s+m+d x max_ingredients] dishes (max 6 dishes total)
  input [4:0] incompatible [0:1][0:1],     // incompatible pairs [n x 2]
  output reg [63:0] result,       // 64-bit result ('too many' is 1e18 threshold)
  output reg done                 // high when computation complete
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COMB_CHECK = 2'b01;
  localparam BRAND_CALC = 2'b10;
  localparam DONE = 2'b11;

  // Constants
  localparam [63:0] THRESHOLD = 64'd1000000000000000000; // 1e18 threshold

  // State machine registers
  reg [1:0] state, next_state;
  reg [2:0] comb_index; // tracks current combination (0-7)
  reg [7:0] ingredient_set; // 8-bit vector to track ingredients in current meal
  reg invalid_comb; // flag for invalid combination due to incompatible pairs
  reg [63:0] temp_result; // temporary result for accumulation
  reg [7:0] product; // product of brand counts (8-bit, max 255)
  reg [2:0] i, j, k; // loop counters

  // Sequential logic for state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      comb_index <= 0;
      ingredient_set <= 0;
      invalid_comb <= 0;
      temp_result <= 0;
      product <= 0;
    end else begin
      state <= next_state;
      
      // Update registers based on state
      case (state)
        IDLE: begin
          if (start) begin
            result <= 0;
            comb_index <= 0;
          end
        end
        
        COMB_CHECK: begin
          // Calculate dish indices for current combination
          s_index = s + (comb_index % 2);
          m_index = m + ((comb_index/2) % 2);
          d_index = d + ((comb_index/4) % 2);
          
          // Form ingredient set
          ingredient_set = 8'b0;
          for (i = 0; i < 8; i++) begin
            if (dish_ingredients[s_index][i] != 5'd0) begin
              ingredient_set[ dish_ingredients[s_index][i][2:0] ] = 1;
            end
          end
          for (i = 0; i < 8; i++) begin
            if (dish_ingredients[m_index][i] != 5'd0) begin
              ingredient_set[ dish_ingredients[m_index][i][2:0] ] = 1;
            end
          end
          for (i = 0; i < 8; i++) begin
            if (dish_ingredients[d_index][i] != 5'd0) begin
              ingredient_set[ dish_ingredients[d_index][i][2:0] ] = 1;
            end
          end
          
          // Check incompatible pairs
          invalid_comb = 0;
          for (i = 0; i < n; i++) begin
            if (ingredient_set[ incompatible[i][0][2:0] ] && 
                ingredient_set[ incompatible[i][1][2:0] ]) begin
              invalid_comb = 1;
            end
          end
          
          comb_index <= comb_index + 1;
        end
        
        BRAND_CALC: begin
          if (!invalid_comb) begin
            // Calculate product of brand counts for ingredients in set
            product = 8'd1;
            for (i = 0; i < 8; i++) begin
              if (ingredient_set[i]) begin
                product = product * brands[i];
              end
            end
            
            // Check for overflow and accumulate
            if (result + product >= THRESHOLD) begin
              result <= THRESHOLD;
            end else begin
              result <= result + product;
            end
          end
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Combinational logic for next state
  always_comb begin
    next_state = state;
    
    case (state)
      IDLE: begin
        if (start) next_state = COMB_CHECK;
      end
      
      COMB_CHECK: begin
        if (comb_index >= 3'd7) begin
          next_state = DONE;
        end else begin
          next_state = BRAND_CALC;
        end
      end
      
      BRAND_CALC: begin
        if (comb_index >= 3'd7) begin
          next_state = DONE;
        end else begin
          next_state = COMB_CHECK;
        end
      end
      
      DONE: begin
        next_state = DONE;
      end
    endcase
  end

  // Immediate termination if threshold exceeded
  always_ff @(posedge clk) begin
    if (state == BRAND_CALC && result + product >= THRESHOLD) begin
      next_state = DONE;
      result <= THRESHOLD;
    end
  end

endmodule