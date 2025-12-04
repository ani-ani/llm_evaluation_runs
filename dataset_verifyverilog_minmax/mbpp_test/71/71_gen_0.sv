module comb_sort(
    input clk,
    input rst_n,
    input start,
    input [63:0] data_in,
    output logic [63:0] data_out,
    output logic done
);

  // Internal registers
  reg [2:0] gap_index;      // Index into gap sequence (0 to 4)
  reg [2:0] current_gap;    // Current gap value
  reg [2:0] pair_index;     // Current pair being compared
  reg swapped;              // Flag indicating if any swap occurred
  reg [7:0] mem [0:7];      // Internal storage for 8 values
  reg [3:0] state, next_state;

  // State encoding
  parameter [3:0] IDLE = 0,
                  LOAD = 1,
                  COMPARE_GAP = 2,
                  SWAP_IF_NEEDED = 3,
                  NEXT_PAIR = 4,
                  UPDATE_GAP = 5,
                  CHECK_SWAPPED = 6,
                  DONE = 7;

  // Gap sequence: 6, 4, 3, 2, 1
  wire [2:0] gap_sequence [0:4];
  assign gap_sequence[0] = 3'd6;
  assign gap_sequence[1] = 3'd4;
  assign gap_sequence[2] = 3'd3;
  assign gap_sequence[3] = 3'd2;
  assign gap_sequence[4] = 3'd1;

  // State machine sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      mem <= '{default:0};
      gap_index <= 0;
      current_gap <= 0;
      pair_index <= 0;
      swapped <= 0;
    end else begin
      state <= next_state;
      
      case (next_state)
        LOAD: begin
          mem[0] <= data_in[7:0];
          mem[1] <= data_in[15:8];
          mem[2] <= data_in[23:16];
          mem[3] <= data_in[31:24];
          mem[4] <= data_in[39:32];
          mem[5] <= data_in[47:40];
          mem[6] <= data_in[55:48];
          mem[7] <= data_in[63:56];
          gap_index <= 0;
          swapped <= 0;
        end
        
        COMPARE_GAP: begin
          if (gap_index < 5) 
            current_gap <= gap_sequence[gap_index];
          else
            current_gap <= gap_sequence[0];  // wrap around
          pair_index <= 0;
        end
        
        SWAP_IF_NEEDED: begin
          if (mem[pair_index] > mem[pair_index + current_gap]) begin
            reg [7:0] temp;
            temp := mem[pair_index];
            mem[pair_index] <= mem[pair_index + current_gap];
            mem[pair_index + current_gap] <= temp;
            swapped <= 1;
          end
        end
        
        NEXT_PAIR: begin
          if (pair_index + current_gap < 8)
            pair_index <= pair_index + 1;
        end
        
        UPDATE_GAP: begin
          gap_index <= gap_index + 1;
          if (gap_index >= 4) 
            gap_index <= 0;  // reset after last gap
        end
        
        CHECK_SWAPPED: begin
          if (current_gap == 1) begin
            if (swapped) begin
              swapped <= 0;
              gap_index <= 0;  // restart sequence
            end
          end
        end
        
        DONE: begin
          // State transitions to IDLE
        end
        
        default: begin
          // Maintain current values for unhandled states
        end
      endcase
    end
  end

  // State machine combinational logic
  always_comb begin
    next_state = state;  // default hold state
    
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      
      LOAD: begin
        next_state = COMPARE_GAP;
      end
      
      COMPARE_GAP: begin
        next_state = SWAP_IF_NEEDED;
      end
      
      SWAP_IF_NEEDED: begin
        next_state = NEXT_PAIR;
      end
      
      NEXT_PAIR: begin
        if (pair_index + current_gap < 8) 
          next_state = SWAP_IF_NEEDED;
        else if (current_gap == 1)
          next_state = CHECK_SWAPPED;
        else
          next_state = UPDATE_GAP;
      end
      
      UPDATE_GAP: begin
        next_state = COMPARE_GAP;
      end
      
      CHECK_SWAPPED: begin
        if (current_gap == 1) begin
          if (swapped)
            next_state = COMPARE_GAP;  // restart sequence
          else
            next_state = DONE;
        end
      end
      
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output assignments
  assign data_out = {mem[7], mem[6], mem[5], mem[4], mem[3], mem[2], mem[1], mem[0]};
  assign done = (state == DONE);

endmodule