module substring_finder (
  input clk,
  input rst_n,
  input start,
  input [127:0] text_data,
  input [63:0] pattern_data,
  output reg [63:0] substring,
  output reg [3:0] start_pos,
  output reg [3:0] end_pos,
  output reg match_found,
  output reg done
);

  reg [3:0] pos;
  reg match_in_progress;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pos <= 4'b0;
      match_found <= 1'b0;
      done <= 1'b0;
      substring <= 64'b0;
      start_pos <= 4'b0;
      end_pos <= 4'b0;
      match_in_progress <= 1'b0;
    end else begin
      if (start) begin
        pos <= 4'b0;
        match_found <= 1'b0;
        done <= 1'b0;
        substring <= 64'b0;
        start_pos <= 4'b0;
        end_pos <= 4'b0;
        match_in_progress <= 1'b1;
      end else if (match_in_progress && !done) begin
        if ((text_data >> (pos * 8))[63:0] == pattern_data) begin
          match_found <= 1'b1;
          substring <= (text_data >> (pos * 8))[63:0];
          start_pos <= pos;
          end_pos <= pos + 4'd7;
          done <= 1'b1;
        end else if (pos == 4'd8) begin
          done <= 1'b1;
        end
        
        pos <= pos + 4'b1;
        
        if (done || pos >= 4'd8) begin
          match_in_progress <= 1'b0;
        end
      end
    end
  end

endmodule