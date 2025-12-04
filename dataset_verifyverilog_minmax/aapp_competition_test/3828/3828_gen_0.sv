module train_sorter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [4:0] car_numbers [0:15],
  output reg [4:0] min_moves,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam LOAD_POS = 2'b01;
  localparam SCAN_SEQ = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state, next_state;
  reg [3:0] load_cycle, scan_cycle;
  reg [4:0] current_len, long_len;
  reg [4:0] pos_array [0:31];
  integer i;

  // State machine sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_moves <= 0;
      long_len <= 0;
      current_len <= 0;
      load_cycle <= 0;
      scan_cycle <= 0;
      for (int j = 0; j < 32; j++) begin
        pos_array[j] <= 0;
      end
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            next_state = LOAD_POS;
            load_cycle <= 0;
            current_len <= 0;
            long_len <= 0;
          end
        end
        
        LOAD_POS: begin
          if (load_cycle < n) begin
            pos_array[car_numbers[load_cycle]] <= load_cycle;
            load_cycle <= load_cycle + 1;
            next_state = LOAD_POS;
          end else begin
            next_state = SCAN_SEQ;
            scan_cycle <= 0;
            current_len <= 1;
            long_len <= 1;
          end
        end
        
        SCAN_SEQ: begin
          i = scan_cycle * 2;
          
          // Process first pair (i, i+1)
          if (i+1 <= 31) begin
            if (pos_array[i+1] > pos_array[i]) begin
              current_len = current_len + 1;
            end else begin
              current_len = 1;
            end
          end
          
          // Process second pair (i+1, i+2)
          if (i+2 <= 31) begin
            if (pos_array[i+2] > pos_array[i+1]) begin
              current_len = current_len + 1;
            end else begin
              current_len = 1;
            end
          end
          
          // Update lengths
          if (current_len > long_len) begin
            long_len = current_len;
          end
          
          // Control scan cycles
          if (scan_cycle < 4'd15) begin
            scan_cycle = scan_cycle + 1;
            next_state = SCAN_SEQ;
          end else begin
            next_state = DONE;
          end
        end
        
        DONE: begin
          min_moves = n - long_len;
          done = 1;
          long_len = 0;
          current_len = 0;
          load_cycle = 0;
          scan_cycle = 0;
          next_state = IDLE;
        end
        
        default: next_state = IDLE;
      endcase
    end
  end
endmodule