module string_sorter (
  input clk,
  input rst_n,
  input start,
  input [63:0][7:0] char_in,
  output reg [63:0][7:0] char_out,
  output reg done
);

  typedef enum logic [2:0] { IDLE, READ, COLLECT, SORT, WRITE, DONE_ST } state_t;
  reg [2:0] state, next_state;
  
  reg [63:0][7:0] char_in_latched;
  reg [5:0] input_ptr;
  reg [5:0] word_start_ptr;
  reg [2:0] word_pos;
  reg [7:0][7:0] word_reg;
  reg [7:0][7:0] word_reg_next;
  reg [3:0] pass;
  reg [2:0] write_pos;
  
  // Bubble sort comb logic
  always_comb begin
    word_reg_next = word_reg;
    if (state == SORT && pass < 8) begin
      for (int j=0; j<7; j++) begin
        if (j < (8 - pass - 1)) begin
          if (word_reg[j] > word_reg[j+1]) begin
            word_reg_next[j] = word_reg[j+1];
            word_reg_next[j+1] = word_reg[j];
          end
        end
      end
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      char_out <= '0;
      input_ptr <= 0;
      word_pos <= 0;
      pass <= 0;
      word_start_ptr <= 0;
      write_pos <= 0;
      char_in_latched <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            char_in_latched <= char_in;
            state <= READ;
            input_ptr <= 0;
            char_out <= '0;
          end
        end
        
        READ: begin
          if (input_ptr >= 64) begin
            state <= DONE_ST;
          end else if (char_in_latched[input_ptr] == 8'h20) begin
            char_out[input_ptr] <= 8'h20;
            input_ptr <= input_ptr + 1;
            state <= READ;
          end else begin
            word_start_ptr <= input_ptr;
            word_pos <= 0;
            word_reg[0] <= char_in_latched[input_ptr];
            word_pos <= 1;
            input_ptr <= input_ptr + 1;
            state <= COLLECT;
          end
        end
        
        COLLECT: begin
          if (input_ptr < 64 && word_pos < 8 && char_in_latched[input_ptr] != 8'h20) begin
            word_reg[word_pos] <= char_in_latched[input_ptr];
            word_pos <= word_pos + 1;
            input_ptr <= input_ptr + 1;
            state <= COLLECT;
          end else begin
            state <= SORT;
            pass <= 0;
          end
        end
        
        SORT: begin
          if (pass < 8) begin
            word_reg <= word_reg_next;
            pass <= pass + 1;
            state <= SORT;
          end else begin
            state <= WRITE;
            write_pos <= 0;
          end
        end
        
        WRITE: begin
          if (write_pos < word_pos) begin
            char_out[word_start_ptr + write_pos] <= word_reg[write_pos];
            write_pos <= write_pos + 1;
          end else begin
            if (input_ptr < 64 && char_in_latched[input_ptr] == 8'h20) begin
              char_out[input_ptr] <= 8'h20;
              input_ptr <= input_ptr + 1;
            end
            state <= (input_ptr < 64) ? READ : DONE_ST;
          end
        end
        
        DONE_ST: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule