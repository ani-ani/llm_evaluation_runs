module paren_depth_calculator (input clk, input rst_n, input start, input [127:0] group_string, output reg [2:0] max_depth, output reg done);
  typedef enum {IDLE, PROCESSING} state_t;
  state_t state;
  reg [2:0] current_depth;
  reg [3:0] char_index;
  reg stop_processing;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      current_depth <= 0;
      max_depth <= 0;
      char_index <= 0;
      stop_processing <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            current_depth <= 0;
            max_depth <= 0;
            char_index <= 0;
            stop_processing <= 0;
          end
        end
        
        PROCESSING: begin
          done <= 0;
          if (!stop_processing) begin
            automatic logic [7:0] current_char = group_string[(15 - char_index)*8 +: 8];
            
            if (current_char == 8'h00)
              stop_processing <= 1;
            else if (current_char == "(") begin
              current_depth <= current_depth + 1;
              if (current_depth + 1 > max_depth)
                max_depth <= current_depth + 1;
            end
            else if (current_char == ")")
              current_depth <= current_depth - 1;
          end
          
          if (char_index == 15) begin
            done <= 1;
            state <= IDLE;
          end
          else
            char_index <= char_index + 1;
        end
      endcase
    end
  end
endmodule