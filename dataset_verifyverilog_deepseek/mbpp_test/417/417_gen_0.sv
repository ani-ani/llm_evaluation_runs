module tuple_grouper (
  input clk,
  input rst_n,
  input start,
  input [0:3][0:2][7:0] tuples,
  input [0:3] valid_tuple,
  output reg [0:3][0:6][7:0] grouped,
  output reg [0:3] valid_group,
  output reg done
);
  
  // State machine
  typedef enum {
    IDLE,
    READ,
    CHECK,
    GROUP,
    FINISH
  } state_t;
  
  state_t current_state;
  
  // Internal registers
  reg [0:3][0:2][7:0] stored_tuples;
  reg [0:3] stored_valid;
  reg [7:0] unique_first [0:3];
  reg [1:0] tuple_group [0:3];
  reg [1:0] group_count;
  reg [0:3][0:6][7:0] grouped_next;
  
  // State transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      stored_tuples <= '0;
      stored_valid <= '0;
      grouped <= '0;
      valid_group <= '0;
      done <= '0;
    
      for (int i = 0; i < 4; i++) begin
        unique_first[i] <= '0;
        tuple_group[i] <= '0;
      end
      group_count <= '0;
    
    end else begin
      case (current_state)
        IDLE: begin
          done <= '0;
          if (start) current_state <= READ;
        end
        
        READ: begin
          stored_tuples <= tuples;
          stored_valid <= valid_tuple;
          current_state <= CHECK;
        end
        
        CHECK: begin
          // Reset group tracking
          group_count <= 0;
          for (int i = 0; i < 4; i++) begin
            unique_first[i] <= '0;
          end
          
          for (int i = 0; i < 4; i++) begin
            if (stored_valid[i]) begin
              // Check for existing group
              bit found = 0;
              for (int j = 0; j < group_count; j++) begin
                if (stored_tuples[i][0] == unique_first[j]) begin
                  tuple_group[i] <= j;
                  found = 1;
                  break;
                end
              end
              if (!found && (group_count < 4)) begin
                unique_first[group_count] <= stored_tuples[i][0];
                tuple_group[i] <= group_count;
                group_count <= group_count + 1;
              end else if (!found) begin
                tuple_group[i] <= 3; // Fallback (shouldn't occur with spec)
              end
            end else begin
              tuple_group[i] <= 0;
            end
          end
          current_state <= GROUP;
        end
        
        GROUP: begin
          grouped_next = '0;
          // Process each group
          for (int g = 0; g < 4; g++) begin
            if (g < group_count) begin
              grouped_next[g][0] = unique_first[g];
              int ptr = 1;
              
              for (int i = 0; i < 4; i++) begin
                if (stored_valid[i] && (tuple_group[i] == g)) begin
                  if (ptr < 7) begin
                    grouped_next[g][ptr] = stored_tuples[i][1];
                    ptr++;
                  end
                  if (ptr < 7) begin
                    grouped_next[g][ptr] = stored_tuples[i][2];
                    ptr++;
                  end
                end
              end
            end
          end
          grouped <= grouped_next;
          valid_group <= (group_count > 0) ? (4'b0001 << group_count) - 1 : '0;
          current_state <= FINISH;
        end
        
        FINISH: begin
          done <= 1'b1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule