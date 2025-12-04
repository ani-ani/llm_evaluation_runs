module hopper_path_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] D,
  input [7:0] M,
  input [15:0] arr_0,
  input [15:0] arr_1,
  input [15:0] arr_2,
  input [15:0] arr_3,
  input [15:0] arr_4,
  input [15:0] arr_5,
  input [15:0] arr_6,
  input [15:0] arr_7,
  output reg [3:0] max_length,
  output reg done
);

  reg [15:0] arr_reg [0:7];
  reg [3:0] dp_table [0:255][0:7];
  reg [7:0] queue_mask [0:63];
  reg [2:0] queue_last_node [0:63];
  reg [3:0] queue_length [0:63];
  reg [5:0] head_ptr, tail_ptr;
  reg queue_not_empty;
  
  reg [1:0] state;
  localparam IDLE = 0, INIT = 1, PROCESS = 2, DONE = 3;

  reg [5:0] cycle_count;
  reg [3:0] global_max;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_length <= 0;
      head_ptr <= 0;
      tail_ptr <= 0;
      queue_not_empty <= 0;
      global_max <= 0;
      for (int m = 0; m < 256; m++) for (int n = 0; n < 8; n++) dp_table[m][n] <= 0;
      for (int i = 0; i < 8; i++) arr_reg[i] <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            arr_reg[0] <= arr_0;
            arr_reg[1] <= arr_1;
            arr_reg[2] <= arr_2;
            arr_reg[3] <= arr_3;
            arr_reg[4] <= arr_4;
            arr_reg[5] <= arr_5;
            arr_reg[6] <= arr_6;
            arr_reg[7] <= arr_7;
            state <= INIT;
          end
        end
        
        INIT: begin
          cycle_count <= 0;
          head_ptr <= 0;
          tail_ptr <= 8;
          global_max <= 1;
          done <= 0;
          
          for (int i = 0; i < 8; i++) begin
            queue_mask[i] <= (1 << i);
            queue_last_node[i] <= i;
            queue_length[i] <= 1;
            dp_table[1<<i][i] <= 1;
          end
          
          queue_not_empty <= 1;
          state <= PROCESS;
        end
        
        PROCESS: begin
          if (cycle_count < 64) begin
            cycle_count <= cycle_count + 1;
            
            if (queue_not_empty) begin
              reg [7:0] current_mask = queue_mask[head_ptr];
              reg [2:0] current_node = queue_last_node[head_ptr];
              reg [3:0] current_length = queue_length[head_ptr];
              head_ptr <= head_ptr + 1;
              queue_not_empty <= (head_ptr + 1 < tail_ptr);
              
              for (int j = 0; j < 8; j++) begin
                if (!current_mask[j]) begin
                  reg [2:0] dist = (current_node > j) ? (current_node - j) : (j - current_node);
                  reg signed [15:0] val_diff = arr_reg[current_node] - arr_reg[j];
                  if ((dist <= D) && ($signed(val_diff) <= $signed(M)) && ($signed(-val_diff) <= $signed(M))) begin
                    reg [7:0] new_mask = current_mask | (1 << j);
                    reg [3:0] new_length = current_length + 1;
                    if (new_length > dp_table[new_mask][j]) begin
                      dp_table[new_mask][j] <= new_length;
                      queue_mask[tail_ptr] <= new_mask;
                      queue_last_node[tail_ptr] <= j;
                      queue_length[tail_ptr] <= new_length;
                      tail_ptr <= tail_ptr + 1;
                      queue_not_empty <= 1;
                      if (new_length > global_max) begin
                        global_max <= new_length;
                      end
                    end
                  end
                end
              end
            end
          end
          else begin
            max_length <= global_max;
            done <= 1;
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule