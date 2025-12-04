module space_replacer(
  input clk,
  input rst_n,
  input start,
  input [127:0] text_in,
  output reg done,
  output reg [127:0] text_out
);
  
  typedef enum {
    IDLE,
    PROCESSING,
    DONE
  } state_t;
  
  reg [1:0] state, next_state;
  reg [3:0] count;
  reg [1:0] space_counter;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      text_out <= 128'b0;
      count <= 4'd0;
      space_counter <= 2'd0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            text_out <= 128'b0;
            count <= 4'd0;
            space_counter <= 2'd0;
          end
        end
        
        PROCESSING: begin
          // Process current character byte
          automatic logic [7:0] current_char;
          current_char = text_in[127 - 8*count -: 8];
          
          if (current_char == 8'h20) begin // space
            if (space_counter < 2'd2) begin
              text_out[127 - 8*count -: 8] <= 8'h5F; // underscore
              space_counter <= space_counter + 1'b1;
            end else begin
              text_out[127 - 8*count -: 8] <= 8'h2D; // hyphen
              space_counter <= 2'd3;
            end
          end else begin // non-space
            text_out[127 - 8*count -: 8] <= current_char;
            space_counter <= 2'd0;
          end
          
          if (count == 4'd15) begin
            next_state <= DONE;
          end
          count <= count + 1'b1;
        end
        
        DONE: begin
          done <= 1'b1;
          next_state <= IDLE;
        end
      endcase
    end
  end
  
  always_comb begin
    case (state)
      IDLE: next_state = start ? PROCESSING : IDLE;
      PROCESSING: next_state = (count == 4'd15) ? DONE : PROCESSING;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule