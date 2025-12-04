module comb_sort(
  input clk,
  input rst_n,
  input start,
  input [63:0] data_in,
  output logic [63:0] data_out,
  output logic done
);
  
  typedef enum logic [2:0] {IDLE, LOAD, COMPARE_GAP, SWAP_IF_NEEDED, UPDATE_GAP, CHECK_SWAPPED, DONE} state_t;
  state_t current_state, next_state;
  
  // Data storage and sorting registers
  logic [7:0][7:0] data_reg;
  logic [7:0] swap_en;
  logic [2:0] gap_num;
  logic [2:0] current_gap;
  logic swapped_flag;
  logic [2:0] current_gap_latch;
  logic [7:0] swap_en_latch;
  logic any_swap_en;
  
  // Assign current_gap from gap_num
  always_comb begin
    case(gap_num)
      0: current_gap = 6;
      1: current_gap = 4;
      2: current_gap = 3;
      3: current_gap = 2;
      4: current_gap = 1;
      default: current_gap = 0;
    endcase
  end
  
  // Compute swap enables for current gap
  always_comb begin
    swap_en = '0;
    for (int i=0; i<8; i++) begin
      if (i < (8 - current_gap)) begin
        swap_en[i] = (data_reg[i] > data_reg[i + current_gap]);
      end
    end
    any_swap_en = |swap_en;
  end
  
  // Next state logic
  always_comb begin
    next_state = current_state;
    case(current_state)
      IDLE: if (start) next_state = LOAD;
      LOAD: next_state = COMPARE_GAP;
      COMPARE_GAP: next_state = any_swap_en ? SWAP_IF_NEEDED : UPDATE_GAP;
      SWAP_IF_NEEDED: next_state = UPDATE_GAP;
      UPDATE_GAP: next_state = (gap_num < 4) ? COMPARE_GAP : CHECK_SWAPPED;
      CHECK_SWAPPED: next_state = swapped_flag ? COMPARE_GAP : DONE;
      DONE: next_state = DONE;
    endcase
  end
  
  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      data_reg <= '0;
      gap_num <= 0;
      swapped_flag <= 0;
      swap_en_latch <= '0;
      current_gap_latch <= 0;
    end else begin
      current_state <= next_state;
      
      case(current_state)
        IDLE: begin
               done <= 0;
               swapped_flag <= 0;
              end
        
        LOAD: begin
          for (int i=0; i<8; i++) 
            data_reg[i] <= data_in[i*8 +:8];
          gap_num <= 0;
          swapped_flag <= 0;
        end
        
        COMPARE_GAP: begin
          swap_en_latch <= swap_en;
          current_gap_latch <= current_gap;
        end
        
        SWAP_IF_NEEDED: begin
          for (int i=0; i<8; i++) begin
            if (i < (8 - current_gap_latch) && swap_en_latch[i]) begin
              data_reg[i] <= data_reg[i + current_gap_latch];
              data_reg[i + current_gap_latch] <= data_reg[i];
            end
          end
          swapped_flag <= 1;
        end
        
        UPDATE_GAP: begin
          if (gap_num < 4) begin
            gap_num <= gap_num + 1;
          end else begin
            gap_num <= 0;
          end
        end
        
        CHECK_SWAPPED: if (swapped_flag) swapped_flag <= 0;
        
        DONE: done <= 1;
      endcase
    end
  end
  
  // Output assignment
  assign data_out = {data_reg[7], data_reg[6], data_reg[5], data_reg[4], 
                    data_reg[3], data_reg[2], data_reg[1], data_reg[0]};

endmodule