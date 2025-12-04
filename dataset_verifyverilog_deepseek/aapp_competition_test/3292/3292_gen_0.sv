module name_ordering_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0][31:0] names,
  output reg [15:0] count,
  output reg done
);

  typedef enum {IDLE, GROUP1, GROUP2, CALC, DONE} state_t;
  state_t curr_state, next_state;

  reg [7:0] fc [0:3];
  reg [7:0] sc [0:3];
  
  wire [2:0] counts [0:3];
  wire [2:0] g1_counts [0:3];
  wire [15:0] l1_product;
  wire [15:0] l2_product;
  
  reg [2:0] group_sizes [0:3];
  reg [2:0] subgroup_sizes [0:3];
  
  reg [1:0] delay_counter;
  
  function [15:0] factorial(input [2:0] n);
    case (n)
      4: factorial = 24;
      3: factorial = 6;
      2: factorial = 2;
      1: factorial = 1;
      default: factorial = 1;
    endcase
  endfunction
  
  // 4-input parallel grouping comparator
  generate
    for (genvar i=0; i<4; i++) begin
      assign counts[i] = (names[0][31:24+8*i] == fc[0]) +
                         (names[1][31:24+8*i] == fc[0]) +
                         (names[2][31:24+8*i] == fc[0]) +
                         (names[3][31:24+8*i] == fc[0]);
    end
  endgenerate
  
  assign l1_product = factorial(group_sizes[0]) * factorial(group_sizes[1]) * 
                     factorial(group_sizes[2]) * factorial(group_sizes[3]);
  
  assign l2_product = factorial(subgroup_sizes[0]) * factorial(subgroup_sizes[1]) * 
                     factorial(subgroup_sizes[2]) * factorial(subgroup_sizes[3]);
  
  always_comb begin
    next_state = curr_state;
    case (curr_state)
      IDLE: if (start) next_state = GROUP1;
      GROUP1: next_state = GROUP2;
      GROUP2: next_state = CALC;
      CALC: next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_state <= IDLE;
      done <= 0;
      count <= 0;
      
      // Init macros
      for (int i=0; i<4; i++) begin
        subgroup_sizes[i] <= 0;
        group_sizes[i] <= 0;
      end
      delay_counter <= 0;
      
    end else begin
      curr_state <= next_state;
      done <= (curr_state == DONE);
      
      case (curr_state)
        IDLE: begin
          count <= 0;
          
          for (int i=0; i<4; i++) begin
            fc[i] <= names[i][31:24];
            sc[i] <= names[i][23:16];
          end
          
          if (start) begin
            // Reset group sizes
            for (int i=0; i<4; i++) begin
              group_sizes[i] <= 0;
            end
          end
        end
        
        GROUP1: begin
          // Load group sizes based on prefix
          for (int i=0; i<4; i++) begin
            group_sizes[i] <= counts[i];
          end
          
          delay_counter <= 0;
          count <= 0;
        end
        
        GROUP2: begin
          // Prepare subgroup counts for next level
          if (delay_counter == 0) begin
            for (int i=0; i<4; i++) begin
              subgroup_sizes[i] <= counts[i]; // for sc
            end
            delay_counter <= delay_counter + 1;
            
          end else if (delay_counter == 1) begin
            count <= l1_product * l2_product;
            delay_counter <= delay_counter + 1;
          end
        end
        
        CALC: begin
          // Final product already computed in GROUP2
          count <= l1_product * l2_product;
        end
        
        DONE: begin
          count <= count;
        end
      endcase
    end
  end
  
endmodule
