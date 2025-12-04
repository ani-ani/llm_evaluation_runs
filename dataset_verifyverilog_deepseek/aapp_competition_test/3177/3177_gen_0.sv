module swap_sort_min_steps(
  input clk, 
  input rst_n, 
  input start, 
  input [3:0][1:0] initial_perm,
  input [5:0][3:0] allowed_swaps,
  input [2:0] m_swaps,
  output reg [3:0] min_steps,
  output reg done
);

typedef enum {IDLE, INIT, PROCESS, CHECK_SORTED, APPLY_SWAPS, DONE} state_t;

function automatic [4:0] perm_to_id(input [7:0] perm);
  case(perm)
    8'b00011011: perm_to_id = 5'd0; //1,2,3,4
    8'b00011110: perm_to_id = 5'd1; //1,2,4,3
    8'b00011011: perm_to_id = 5'd2; //1,3,2,4
    8'b00101110: perm_to_id = 5'd3; //1,3,4,2
    8'b00111100: perm_to_id = 5'd4; //1,4,2,3
    8'b00111010: perm_to_id = 5'd5; //1,4,3,2

    8'b01000011: perm_to_id = 5'd6; //2,1,3,4
    8'b01001110: perm_to_id = 5'd7; //2,1,4,3
    8'b01001011: perm_to_id = 5'd8; //2,3,1,4
    8'b01011100: perm_to_id = 5'd9; //2,3,4,1
    8'b01101100: perm_to_id = 5'd10; //2,4,1,3
    8'b01101010: perm_to_id = 5'd11; //2,4,3,1

    8'b10000111: perm_to_id = 5'd12; //3,1,2,4
    8'b10001110: perm_to_id = 5'd13; //3,1,4,2
    8'b10010011: perm_to_id = 5'd14; //3,2,1,4
    8'b10011100: perm_to_id = 5'd15; //3,2,4,1
    8'b10110100: perm_to_id = 5'd16; //3,4,1,2
    8'b10111000: perm_to_id = 5'd17; //3,4,2,1

    8'b11001011: perm_to_id = 5'd18; //4,1,2,3
    8'b11001110: perm_to_id = 5'd19; //4,1,3,2
    8'b11010011: perm_to_id = 5'd20; //4,2,1,3
    8'b11011010: perm_to_id = 5'd21; //4,2,3,1
    8'b11100110: perm_to_id = 5'd22; //4,3,1,2
    8'b11101001: perm_to_id = 5'd23; //4,3,2,1
    default: perm_to_id = 5'd0;
  endcase
endfunction

function automatic [7:0] id_to_perm(input [4:0] id);
  case(id)
    5'd0: id_to_perm = 8'b00011011; //1,2,3,4
    5'd1: id_to_perm = 8'b00011110; //1,2,4,3
    5'd2: id_to_perm = 8'b00100111; //1,3,2,4
    5'd3: id_to_perm = 8'b00101110; //1,3,4,2
    5'd4: id_to_perm = 8'b00111100; //1,4,2,3
    5'd5: id_to_perm = 8'b00111010; //1,4,3,2

    5'd6: id_to_perm = 8'b01000011; //2,1,3,4
    5'd7: id_to_perm = 8'b01001110; //2,1,4,3
    5'd8: id_to_perm = 8'b01001011; //2,3,1,4
    5'd9: id_to_perm = 8'b01011100; //2,3,4,1
    5'd10: id_to_perm = 8'b01101100; //2,4,1,3
    5'd11: id_to_perm = 8'b01101010; //2,4,3,1

    5'd12: id_to_perm = 8'b10000111; //3,1,2,4
    5'd13: id_to_perm = 8'b10001110; //3,1,4,2
    5'd14: id_to_perm = 8'b10010011; //3,2,1,4
    5'd15: id_to_perm = 8'b10011100; //3,2,4,1
    5'd16: id_to_perm = 8'b10110100; //3,4,1,2
    5'd17: id_to_perm = 8'b10111000; //3,4,2,1

    5'd18: id_to_perm = 8'b11001011; //4,1,2,3
    5'd19: id_to_perm = 8'b11001110; //4,1,3,2
    5'd20: id_to_perm = 8'b11010011; //4,2,1,3
    5'd21: id_to_perm = 8'b11011010; //4,2,3,1
    5'd22: id_to_perm = 8'b11100110; //4,3,1,2
    5'd23: id_to_perm = 8'b11101001; //4,3,2,1
    default: id_to_perm = 8'b00011011;
  endcase
endfunction

function automatic [7:0] apply_swap(input [7:0] perm, input [3:0] swap_pair);
  reg [1:0] a_idx, b_idx;
  reg [1:0] a_val, b_val;
  reg [7:0] swapped;
  begin
    a_idx = swap_pair[3:2];
    b_idx = swap_pair[1:0];
    swapped = perm;
    
    case(a_idx)
      2'd0: a_val = perm[7:6];
      2'd1: a_val = perm[5:4];
      2'd2: a_val = perm[3:2];
      2'd3: a_val = perm[1:0];
    endcase
    
    case(b_idx)
      2'd0: b_val = perm[7:6];
      2'd1: b_val = perm[5:4];
      2'd2: b_val = perm[3:2];
      2'd3: b_val = perm[1:0];
    endcase
    
    case(a_idx)
      2'd0: swapped[7:6] = b_val;
      2'd1: swapped[5:4] = b_val;
      2'd2: swapped[3:2] = b_val;
      2'd3: swapped[1:0] = b_val;
    endcase
    
    case(b_idx)
      2'd0: swapped[7:6] = a_val;
      2'd1: swapped[5:4] = a_val;
      2'd2: swapped[3:2] = a_val;
      2'd3: swapped[1:0] = a_val;
    endcase
    
    apply_swap = swapped;
  end
endfunction

reg [4:0] queue [0:23];
reg [4:0] head_ptr, tail_ptr;
reg [23:0] visited;
reg [3:0] dist [0:23];
reg [7:0] initial_perm_reg;
reg [4:0] current_id;
reg [7:0] current_perm;
reg [2:0] swap_idx;
state_t state;

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    min_steps <= 4'b0;
    visited <= 24'b0;
    head_ptr <= 5'b0;
    tail_ptr <= 5'b0;
    swap_idx <= 3'b0;
  end else begin
    case(state)
      IDLE: begin
        done <= 1'b0;
        min_steps <= 4'b0;
        if(start) begin
          initial_perm_reg <= {initial_perm[3], initial_perm[2], initial_perm[1], initial_perm[0]};
          state <= INIT;
        end
      end
      
      INIT: begin
        visited <= 24'b0;
        head_ptr <= 5'b0;
        tail_ptr <= 5'd1;
        current_id <= perm_to_id(initial_perm_reg);
        queue[0] <= perm_to_id(initial_perm_reg);
        visited[perm_to_id(initial_perm_reg)] <= 1'b1;
        dist[perm_to_id(initial_perm_reg)] <= 4'b0;
        current_perm <= initial_perm_reg;
        state <= PROCESS;
      end
      
      PROCESS: begin
        if(head_ptr != tail_ptr) begin
          current_id <= queue[head_ptr];
          current_perm <= id_to_perm(queue[head_ptr]);
          head_ptr <= head_ptr + 1;
          state <= CHECK_SORTED;
        end else begin
          min_steps <= 4'b1111;
          done <= 1'b1;
          state <= DONE;
        end
      end
      
      CHECK_SORTED: begin
        if(current_id == 5'd0) begin // Sorted ID
          min_steps <= dist[current_id];
          done <= 1'b1;
          state <= DONE;
        end else begin
          swap_idx <= 3'b0;
          state <= APPLY_SWAPS;
        end
      end
      
      APPLY_SWAPS: begin
        if(swap_idx < m_swaps) begin
          begin
            reg [7:0] new_perm;
            reg [4:0] new_id;
            new_perm = apply_swap(current_perm, allowed_swaps[swap_idx]);
            new_id = perm_to_id(new_perm);
            if(!visited[new_id]) begin
              visited[new_id] <= 1'b1;
              dist[new_id] <= dist[current_id] + 1;
              queue[tail_ptr] <= new_id;
              tail_ptr <= tail_ptr + 1;
            end
          end
          swap_idx <= swap_idx + 1;
        end else begin
          state <= PROCESS;
        end
      end
      
      DONE: begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule