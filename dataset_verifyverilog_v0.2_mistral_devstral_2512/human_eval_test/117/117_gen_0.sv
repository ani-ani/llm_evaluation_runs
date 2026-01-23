module select_words (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] n,
  input [4:0] char_index,
  input valid,
  output reg done,
  output reg [2:0] word_count,
  output reg [7:0] words [0:3][0:7]
);

  // FSM States
  typedef enum logic [2:0] {
    IDLE,
    RECEIVE,
    PARSE,
    CHECK,
    STORE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] current_word [0:7];
  reg [3:0] word_length;
  reg [3:0] consonant_count;
  reg [1:0] word_ptr;
  reg [4:0] index;
  reg [3:0] char_pos;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      word_count <= 3'd0;
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 8; j++) begin
          words[i][j] <= 8'h00;
        end
      end
      current_state <= IDLE;
      word_length <= 4'd0;
      consonant_count <= 4'd0;
      word_ptr <= 2'd0;
      index <= 5'd0;
      char_pos <= 4'd0;
      for (int k = 0; k < 8; k++) begin
        current_word[k] <= 8'h00;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // FSM Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            next_state <= RECEIVE;
          end else begin
            next_state <= IDLE;
          end
        end
        RECEIVE: begin
          if (valid) begin
            next_state <= PARSE;
          end else begin
            next_state <= RECEIVE;
          end
        end
        PARSE: begin
          if (char_index == 5'd16) begin
            next_state <= CHECK;
          end else if (char_in == 8'h20) begin
            next_state <= CHECK;
          end else begin
            next_state <= RECEIVE;
          end
        end
        CHECK: begin
          if (consonant_count == n && word_length > 0) begin
            next_state <= STORE;
          end else if (index == 5'd16) begin
            next_state <= DONE;
          end else begin
            next_state <= RECEIVE;
          end
        end
        STORE: begin
          if (word_ptr == 2'd3) begin
            next_state <= DONE;
          end else if (index == 5'd16) begin
            next_state <= DONE;
          end else begin
            next_state <= RECEIVE;
          end
        end
        DONE: begin
          next_state <= IDLE;
        end
        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Processing Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (current_state)
        RECEIVE: begin
          if (valid) begin
            index <= char_index;
            if (char_in != 8'h20 && index < 5'd16) begin
              current_word[char_pos] <= char_in;
              char_pos <= char_pos + 1'b1;
              word_length <= word_length + 1'b1;
              // Check if consonant
              if ((char_in >= 8'h41 && char_in <= 8'h5A) || (char_in >= 8'h61 && char_in <= 8'h7A)) begin
                if (!(char_in == 8'h41 || char_in == 8'h45 || char_in == 8'h49 || char_in == 8'h4F || char_in == 8'h55 ||
                      char_in == 8'h61 || char_in == 8'h65 || char_in == 8'h69 || char_in == 8'h6F || char_in == 8'h75)) begin
                  consonant_count <= consonant_count + 1'b1;
                end
              end
            end
          end
        end
        CHECK: begin
          if (consonant_count == n && word_length > 0 && word_ptr < 2'd4) begin
            for (int i = 0; i < 8; i++) begin
              words[word_ptr][i] <= current_word[i];
            end
            word_count <= word_count + 1'b1;
            word_ptr <= word_ptr + 1'b1;
          end
          // Reset for next word
          word_length <= 4'd0;
          consonant_count <= 4'd0;
          char_pos <= 4'd0;
          for (int j = 0; j < 8; j++) begin
            current_word[j] <= 8'h00;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          // No action
        end
      endcase
    end
  end

endmodule