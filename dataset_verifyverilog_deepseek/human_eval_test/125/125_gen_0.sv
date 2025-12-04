module word_splitter (
  input clk,
  input rst_n,
  input start,
  input [127:0] text_in,
  output reg [4:0] result,
  output reg done
);

  reg [4:0] cycle_counter;
  reg [4:0] splitter_count;
  reg [4:0] letter_count;
  reg found_splitter;
  reg processing;

  wire [7:0] current_char = text_in[{cycle_counter[3:0], 3'b000} +: 8];

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      result <= 5'b0;
      done <= 1'b0;
      cycle_counter <= 5'b0;
      splitter_count <= 5'b0;
      letter_count <= 5'b0;
      found_splitter <= 1'b0;
      processing <= 1'b0;
    end else begin
      done <= 1'b0;
      
      if (processing) begin
        if (cycle_counter < 5'b10000) begin
          if (current_char == 8'h20 || current_char == 8'h2C) begin
            splitter_count <= splitter_count + 5'b1;
            found_splitter <= 1'b1;
          end
          if (current_char >= 8'h61 && current_char <= 8'h7A && (~current_char[0])) begin
            letter_count <= letter_count + 5'b1;
          end
          cycle_counter <= cycle_counter + 5'b1;
        end else if (cycle_counter == 5'b10000) begin
          result <= found_splitter ? (splitter_count + 5'b1) : letter_count;
          done <= 1'b1;
          processing <= 1'b0;
        end
      end else if (start) begin
        processing <= 1'b1;
        cycle_counter <= 5'b0;
        splitter_count <= 5'b0;
        letter_count <= 5'b0;
        found_splitter <= 1'b0;
      end
    end
  end

endmodule