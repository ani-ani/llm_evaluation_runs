module paren_grouper(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_array [0:15],
  output reg [3:0] group_start [0:3],
  output reg [3:0] group_end [0:3],
  output reg [1:0] group_count,
  output reg done
);
  
  // State definitions
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam VALIDATE = 2'b10;
  localparam DONE = 2'b11;
  
  // Internal signals
  reg [1:0] state, next_state;
  reg [3:0] pos;
  reg [2:0] bal;
  reg [2:0] current_group;
  reg invalid;
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos <= 4'b0;
      bal <= 3'b0;
      current_group <= 3'b0;
      invalid <= 1'b0;
      group_start[0] <= 4'b0;
      group_start[1] <= 4'b0;
      group_start[2] <= 4'b0;
      group_start[3] <= 4'b0;
      group_end[0] <= 4'b0;
      group_end[1] <= 4'b0;
      group_end[2] <= 4'b0;
      group_end[3] <= 4'b0;
      group_count <= 2'b0;
      done <= 1'b0;
    end
    else begin
      state <= next_state;
      case (state)
        IDLE: begin
          if (start) begin
            next_state = PROCESSING;
          end
          else begin
            next_state = IDLE;
          end
        end
        
        PROCESSING: begin
          if (char_array[pos] == 8'h20) begin
            // Space: do nothing
          end
          else if (char_array[pos] == 8'h28) begin
            if (bal + 1 > 3) begin
              invalid <= 1'b1;
            end
            else begin
              bal <= bal + 1;
              if (bal + 1 == 1) begin
                if (current_group < 4) begin
                  group_start[current_group] <= pos;
                end
                current_group <= current_group + 1;
              end
            end
          end
          else if (char_array[pos] == 8'h29) begin
            if (bal - 1 < 0) begin
              invalid <= 1'b1;
            end
            else begin
              bal <= bal - 1;
              if (bal - 1 == 0) begin
                if (current_group > 0) begin
                  group_end[current_group - 1] <= pos;
                end
              end
            end
          end
          
          if (pos < 4'b1111) begin
            pos <= pos + 1;
          end
          
          if (invalid) begin
            next_state = VALIDATE;
          end
          else if (pos == 4'b1111) begin
            next_state = VALIDATE;
          end
          else if (current_group == 3'b100) begin
            next_state = VALIDATE;
          end
          else begin
            next_state = PROCESSING;
          end
        end
        
        VALIDATE: begin
          if (invalid || bal != 3'b0) begin
            group_count <= 2'b0;
          end
          else begin
            if (current_group >= 3'b100) begin
              group_count <= 2'b11;
            end
            else begin
              group_count <= current_group[1:0];
            end
          end
          next_state = DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          next_state = IDLE;
        end
        
        default: next_state = IDLE;
      endcase
    end
  end
  
endmodule