module string_splitter (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [511:0] words_out,
  output reg [3:0] word_count,
  output reg done
);

reg processing;
reg [3:0] cycle_counter;
reg [127:0] current_word;
reg [4:0] current_pos;
reg in_word;
reg [127:0] word_data [0:3];

wire [7:0] current_byte = str_in[ (15 - cycle_counter)*8 +: 8 ];

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    processing <= 1'b0;
    cycle_counter <= 4'd0;
    current_word <= 128'd0;
    current_pos <= 5'd0;
    in_word <= 1'b0;
    word_count <= 4'd0;
    words_out <= 512'd0;
    done <= 1'b0;
    word_data[0] <= 128'd0;
    word_data[1] <= 128'd0;
    word_data[2] <= 128'd0;
    word_data[3] <= 128'd0;
  end else begin
    words_out <= {word_data[3], word_data[2], word_data[1], word_data[0]};
    done <= 1'b0;

    if (start && !processing) begin
      processing <= 1'b1;
      cycle_counter <= 4'd0;
      current_word <= 128'd0;
      current_pos <= 5'd0;
      in_word <= 1'b0;
      word_count <= 4'd0;
      word_data[0] <= 128'd0;
      word_data[1] <= 128'd0;
      word_data[2] <= 128'd0;
      word_data[3] <= 128'd0;
    end else if (processing) begin
      if (current_byte == 8'h20) begin
        if (in_word) begin
          if (word_count < 4'd4) begin
            word_data[word_count] <= current_word;
            word_count <= word_count + 4'd1;
          end
          current_word <= 128'd0;
          current_pos <= 5'd0;
          in_word <= 1'b0;
        end
      end else begin
        if (!in_word) begin
          if (word_count < 4'd4) begin
            in_word <= 1'b1;
            current_word[ (15 - current_pos)*8 +:8 ] <= current_byte;
            current_pos <= current_pos + 5'd1;
          end
        end else if (current_pos < 5'd16) begin
          current_word[ (15 - current_pos)*8 +:8 ] <= current_byte;
          current_pos <= current_pos + 5'd1;
        end
      end

      if (cycle_counter == 4'd15) begin
        if (in_word && word_count < 4'd4) begin
          word_data[word_count] <= current_word;
          word_count <= word_count + 4'd1;
        end
        processing <= 1'b0;
        done <= 1'b1;
      end else begin
        cycle_counter <= cycle_counter + 4'd1;
      end
    end
  end
end

endmodule