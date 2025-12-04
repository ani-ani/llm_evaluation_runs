module prime_length_filter(
  input clk,
  input rst_n,
  input start,
  input [2:0] word_count,
  input [7:0][7:0] words [0:7],
  output reg [63:0] filtered_sentence,
  output reg [2:0] word_lengths [0:7],
  output reg done
);

  localparam S_IDLE = 1'b0;
  localparam S_FILTER = 1'b1;

  logic state, next_state;
  logic [2:0] idx, next_idx;
  logic [3:0] processed, next_processed;
  logic [6:0] out_byte_idx, next_out_byte_idx;
  logic [63:0] next_filtered_sentence;
  logic [2:0] next_word_lengths [0:7];
  logic [2:0] lens [0:7];
  logic is_prime_len [0:7];

  genvar g;
  generate
    for (g = 0; g < 8; g = g + 1) begin : LEN
      always @(*) begin
        casez (words[g])
          8'b????????: lens[g] = (words[g][7] !== 0) + (words[g][6] !== 0) + (words[g][5] !== 0) + (words[g][4] !== 0) +
                                 (words[g][3] !== 0) + (words[g][2] !== 0) + (words[g][1] !== 0) + (words[g][0] !== 0);
          default:     lens[g] = 0;
        endcase
        is_prime_len[g] = (lens[g] == 2) || (lens[g] == 3) || (lens[g] == 5) || (lens[g] == 7);
      end
    end
  endgenerate

  always @(*) begin
    next_state = state;
    next_idx = idx;
    next_processed = processed;
    next_out_byte_idx = out_byte_idx;
    next_filtered_sentence = filtered_sentence;
    next_word_lengths = word_lengths;

    case (state)
      S_IDLE: begin
        next_processed = 0;
        next_out_byte_idx = 7;
        if (start) begin
          next_state = S_FILTER;
          next_idx = 0;
        end
      end

      S_FILTER: begin
        if (idx < word_count) begin
          next_word_lengths = word_lengths;
          next_word_lengths[idx] = lens[idx];
          next_filtered_sentence = filtered_sentence;

          if (is_prime_len[idx]) begin
            for (int b = 0; b < 8; b = b + 1) begin
              if (b < lens[idx]) begin
                next_filtered_sentence[8 * out_byte_idx +: 8] = words[idx][b];
              end
            end
            next_out_byte_idx = out_byte_idx - lens[idx];
          end

          next_idx = idx + 1;
          next_processed = processed + 1;
        end else begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      idx <= 0;
      processed <= 0;
      out_byte_idx <= 7;
      filtered_sentence <= 0;
      for (int k = 0; k < 8; k = k + 1) begin
        word_lengths[k] <= 0;
      end
      done <= 0;
    end else begin
      state <= next_state;
      idx <= next_idx;
      processed <= next_processed;
      out_byte_idx <= next_out_byte_idx;
      filtered_sentence <= next_filtered_sentence;
      word_lengths <= next_word_lengths;
      done <= (next_processed == 8);
    end
  end
endmodule