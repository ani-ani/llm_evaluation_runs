module min_plus_adder(
  input clk,
  input rst_n,
  input start,
  input [3:0] digit_count,
  input [7:0][3:0] digits,
  input [15:0] target_sum,
  output reg [6:0] plus_positions,
  output reg [3:0] plus_count,
  output reg [15:0] computed_sum,
  output reg done
);

  // BFS queue storage (128 entries × 7 bits)
  reg [6:0] queue [0:127];
  reg [6:0] rd_ptr, wr_ptr;
  reg queue_full, queue_empty;
  
  // Visited masks array (128 bits)
  reg [127:0] visited;
  
  // Current mask being processed
  reg [6:0] current_mask;
  
  // State machine states
  parameter IDLE = 2'b00;
  parameter BFS  = 2'b01;
  parameter DONE = 2'b10;
  parameter NOT_FOUND = 2'b11;
  
  reg [1:0] state;
  
  // Combinational sum calculation
  reg [31:0] sum_calc;
  reg [31:0] segment_val;
  integer i;
  
  always_comb begin
    sum_calc = 0;
    segment_val = 0;
    for (i = 0; i < 8; i++) begin
      if (i < digit_count) begin
        segment_val = (segment_val * 10) + digits[i];
        if ((i == digit_count-1) || ((i < digit_count-1) && (current_mask[i] == 1))) begin
          sum_calc = sum_calc + segment_val;
          segment_val = 0;
        end
      end
    end
  end
  
  // Combinational popcount for plus_count
  reg [3:0] popcount;
  reg [3:0] pc_i;
  
  always_comb begin
    popcount = 0;
    for (pc_i = 0; pc_i < 7; pc_i++) begin
      if (current_mask[pc_i]) popcount = popcount + 1;
    end
  end
  
  // BFS state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      plus_positions <= 7'h00;
      plus_count <= 4'h0;
      computed_sum <= 16'h0000;
      done <= 1'b0;
      rd_ptr <= 7'h00;
      wr_ptr <= 7'h00;
      queue_full <= 1'b0;
      queue_empty <= 1'b1;
      visited <= 128'h00000000000000000000000000000000;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize with empty mask
            queue[0] = 7'h00;
            visited[0] = 1'b1;
            rd_ptr = 7'h01;
            wr_ptr = 7'h01;
            queue_full = 1'b0;
            queue_empty = 1'b0;
            state = BFS;
          end
        end
        
        BFS: begin
          if (queue_empty) begin
            state = NOT_FOUND;
          end else begin
            // Dequeue current mask
            current_mask = queue[rd_ptr];
            rd_ptr = (rd_ptr + 1) % 128;
            
            // Update queue status
            if (rd_ptr == wr_ptr) queue_empty = 1'b1;
            queue_full = 1'b0;
            
            // Check if current mask matches target sum
            if (sum_calc == target_sum) begin
              plus_positions = current_mask;
              plus_count = popcount;
              computed_sum = sum_calc[15:0];
              done = 1'b1;
              state = DONE;
            end else begin
              // Generate children masks (add one more plus)
              for (i = 0; i < 7; i++) begin
                if ((i < (digit_count-1)) && (current_mask[i] == 0)) begin
                  if (visited[queue[wr_ptr]] == 1'b0) begin
                    queue[wr_ptr] = current_mask | (1 << i);
                    visited[queue[wr_ptr]] = 1'b1;
                    wr_ptr = (wr_ptr + 1) % 128;
                    if (wr_ptr == rd_ptr) queue_full = 1'b1;
                  end
                end
              end
            end
          end
        end
        
        DONE: begin
          done <= 1'b1;
        end
        
        NOT_FOUND: begin
          done <= 1'b1;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
endmodule