module text_encoder (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [15:0],
  output reg [7:0] data_out [15:0],
  output reg done
);

  reg [4:0] counter;

  wire [7:0] current_char = (counter < 16) ? data_in[counter[3:0]] : 8'h00;
  wire is_upper = (current_char >= 8'h41 && current_char <= 8'h5A);
  wire is_lower = (current_char >= 8'h61 && current_char <= 8'h7A);
  wire [7:0] swapped_char = is_upper ? (current_char + 8'h20) :
                             is_lower ? (current_char - 8'h20) :
                             current_char;
  wire is_vowel = (swapped_char == 8'h41) || (swapped_char == 8'h45) || 
                  (swapped_char == 8'h49) || (swapped_char == 8'h4F) || 
                  (swapped_char == 8'h55) || (swapped_char == 8'h61) || 
                  (swapped_char == 8'h65) || (swapped_char == 8'h69) || 
                  (swapped_char == 8'h6F) || (swapped_char == 8'h75);
  wire [7:0] processed_char = is_vowel ? (swapped_char + 8'h02) : swapped_char;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 5'd0;
      done <= 1'b0;
      foreach (data_out[i]) data_out[i] <= 8'h00;
    end else begin
      if (start) begin
        counter <= 5'd0;
        done <= 1'b0;
      end else if (counter < 5'd16) begin
        data_out[counter[3:0]] <= processed_char;
        counter <= counter + 5'd1;
        done <= 1'b0;
      end else begin
        done <= 1'b1;
      end
    end
  end

endmodule