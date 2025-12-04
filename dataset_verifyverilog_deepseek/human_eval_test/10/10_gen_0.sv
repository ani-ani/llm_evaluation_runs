module shortest_palindrome (
  input clk,
  input rst_n,
  input start,
  input [63:0] in_string,
  output reg [127:0] out_palindrome,
  output reg done
);
  
  parameter CHAR_WIDTH = 8;
  
  typedef enum logic [1:0] {
    IDLE,
    CHECKING,
    APPENDING,
    DONE
  } state_t;
  
  state_t state, next_state;
  
  reg [63:0] input_reg;
  reg [2:0] current_suffix_length;
  reg [2:0] start_index;
  wire is_palindrome;
  
  wire [CHAR_WIDTH-1:0] input_chars [0:7];
  assign input_chars[0] = input_reg[7:0];
  assign input_chars[1] = input_reg[15:8];
  assign input_chars[2] = input_reg[23:16];
  assign input_chars[3] = input_reg[31:24];
  assign input_chars[4] = input_reg[39:32];
  assign input_chars[5] = input_reg[47:40];
  assign input_chars[6] = input_reg[55:48];
  assign input_chars[7] = input_reg[63:56];
  
  always_comb begin
    case (current_suffix_length)
      3'd8: is_palindrome = (input_chars[0]==input_chars[7]) 
                          & (input_chars[1]==input_chars[6]) 
                          & (input_chars[2]==input_chars[5]) 
                          & (input_chars[3]==input_chars[4]);
      3'd7: is_palindrome = (input_chars[1]==input_chars[7]) 
                          & (input_chars[2]==input_chars[6]) 
                          & (input_chars[3]==input_chars[5]);
      3'd6: is_palindrome = (input_chars[2]==input_chars[7]) 
                          & (input_chars[3]==input_chars[6]) 
                          & (input_chars[4]==input_chars[5]);
      3'd5: is_palindrome = (input_chars[3]==input_chars[7]) 
                          & (input_chars[4]==input_chars[6]);
      3'd4: is_palindrome = (input_chars[4]==input_chars[7]) 
                          & (input_chars[5]==input_chars[6]);
      3'd3: is_palindrome = (input_chars[5]==input_chars[7]);
      3'd2: is_palindrome = (input_chars[6]==input_chars[7]);
      3'd1: is_palindrome = 1'b1;
      default: is_palindrome = 1'b0;
    endcase
  end
  
  wire [127:0] out_pal_next;
  assign out_pal_next[63:0] = input_reg;
  generate
    genvar j;
    for (j=0; j<8; j=j+1) begin: append_gen
      assign out_pal_next[64+j*8 +:8] = (j < start_index) ? 
        input_reg[(start_index-1-j)*8 +:8] : 8'b0;
    end
  endgenerate
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      out_palindrome <= 128'b0;
      done <= 1'b0;
      input_reg <= 64'b0;
      current_suffix_length <= 3'b0;
      start_index <= 3'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            input_reg <= in_string;
            current_suffix_length <= 3'd8;
            state <= CHECKING;
          end
        end
        
        CHECKING: begin
          done <= 1'b0;
          if (is_palindrome) begin
            start_index <= 3'd8 - current_suffix_length;
            state <= APPENDING;
          end else begin
            current_suffix_length <= current_suffix_length - 1;
          end
        end
        
        APPENDING: begin
          out_palindrome <= out_pal_next;
          state <= DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule