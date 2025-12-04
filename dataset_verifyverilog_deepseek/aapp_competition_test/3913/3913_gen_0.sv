module word_guess_analyzer(input clk, input rst_n, input start, input [3:0] n, input [95:0] revealed_chars, input [3:0] m, input [79:0] word_data, input word_valid, output reg [4:0] result, output reg done);
  typedef enum logic [2:0] {IDLE, PROCESSING, WAIT1, WAIT2} state_t;
  state_t state, next_state;
  reg [3:0] m_reg, n_reg;
  reg [3:0] word_counter;
  reg [31:0] intersection_mask;
  reg [31:0] revealed_letters_mask;
  reg [31:0] word_letters_mask;
  reg [4:0] next_result;
  function automatic [4:0] popcount(input [31:0] vec);
    popcount = 0;
    for (int i=0; i<32; i=i+1) popcount += vec[i];
  endfunction
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      intersection_mask <= '1;
      m_reg <= 0;
      n_reg <= 0;
      word_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            m_reg <= m;
            n_reg <= n;
            intersection_mask <= '1;
            revealed_letters_mask <= 0;
            for (int i=0; i<16; i=i+1) begin
              if (i < n && revealed_chars[i*6+5]) 
                revealed_letters_mask[revealed_chars[i*6 +:5]] <= 1'b1;
            end
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          if (word_valid) begin
            word_letters_mask <= 0;
            for (int i=0; i<16; i=i+1) begin
              if (i < n_reg) begin
                if (revealed_chars[i*6+5]) begin
                  if (word_data[i*5 +:5] != revealed_chars[i*6 +:5]) 
                    word_letters_mask <= 0;
                end else begin
                  if (revealed_letters_mask[word_data[i*5 +:5]]) 
                    word_letters_mask <= 0;
                  else 
                    word_letters_mask[word_data[i*5 +:5]] <= 1'b1;
                end
              end
            end
            if (|word_letters_mask) intersection_mask <= intersection_mask & word_letters_mask;
            if (word_counter == m_reg - 1) begin
              state <= WAIT1;
              word_counter <= 0;
            end else word_counter <= word_counter + 1;
          end
        end
        WAIT1: begin
          result <= popcount(intersection_mask);
          state <= WAIT2;
        end
        WAIT2: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule