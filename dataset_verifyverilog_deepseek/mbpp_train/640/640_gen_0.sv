module remove_parentheses (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [127:0] str_out,
  output reg done
);
  typedef enum {IDLE, PROCESSING} state_t;
  reg state, next_state;
  reg skip_mode;
  reg [3:0] counter;
  reg [127:0] out_buf;
  reg [3:0] wr_count;
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PROCESSING;
      PROCESSING: if (counter == 15) next_state = IDLE;
    endcase
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      skip_mode <= 0;
      counter <= 0;
      out_buf <= 0;
      wr_count <= 0;
      done <= 0;
      str_out <= 0;
    end else begin
      state <= next_state;
      done <= 0;
      
      if (state == PROCESSING) begin
        reg [7:0] current_char;
        current_char = str_in[ (15 - counter) * 8 +: 8 ];
        
        if (current_char == 8'(") begin
          skip_mode <= 1'b1;
        end else if (current_char == 8')") begin
          skip_mode <= 1'b0;
        end else if (!skip_mode) begin
          out_buf <= out_buf | (current_char << (128 - (wr_count * 8) - 8));
          wr_count <= wr_count + 1;
        end
        
        counter <= counter + 1;
        
        if (counter == 15) begin
          str_out <= out_buf;
          done <= 1'b1;
        end
      end
      
      if (next_state == IDLE) begin
        skip_mode <= 1'b0;
        counter <= 0;
        out_buf <= 0;
        wr_count <= 0;
      end
    end
  end
endmodule