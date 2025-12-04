module first_even_odd_product(
  input clk,
  input rst_n,
  input start,
  input [7:0] list [0:7],
  output reg [15:0] product,
  output reg done,
  output reg found_pair
);

  reg [3:0] index;
  reg processing;
  reg found_even, found_odd;
  reg [7:0] first_even_val, first_odd_val;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      processing <= 0;
      found_even <= 0;
      found_odd <= 0;
      first_even_val <= 0;
      first_odd_val <= 0;
      product <= 16'hFFFF;
      done <= 0;
      found_pair <= 0;
    end
    else begin
      done <= 0;
      if (processing) begin
        if (index < 8) begin
          if (!found_even && (list[index][0] == 0)) begin
            first_even_val <= list[index];
            found_even <= 1;
          end
          if (!found_odd && (list[index][0] == 1)) begin
            first_odd_val <= list[index];
            found_odd <= 1;
          end
          index <= index + 1;
        end
        else begin
          if (found_even && found_odd) begin
            product <= first_even_val * first_odd_val;
            found_pair <= 1;
          end
          else begin
            product <= 16'hFFFF;
            found_pair <= 0;
          end
          done <= 1;
          processing <= 0;
        end
      end
      else if (start) begin
        processing <= 1;
        index <= 0;
        found_even <= 0;
        found_odd <= 0;
        product <= 16'hFFFF;
        found_pair <= 0;
      end
    end
  end

endmodule