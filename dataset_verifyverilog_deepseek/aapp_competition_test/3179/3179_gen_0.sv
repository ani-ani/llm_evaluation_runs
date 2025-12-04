module canyon_mapper (
  input clk,
  input rst_n,
  input start,
  input [15:0] x0, y0, x1, y1, x2, y2, x3, y3,
  output reg [31:0] side_length,
  output reg done
);

  logic [3:0] counter;
  logic computing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      side_length <= 0;
      done <= 0;
      computing <= 0;
      counter <= 0;
    end else begin
      done <= 0;
      if (start && !computing) begin
        automatic logic signed [15:0] min_x, max_x, min_y, max_y;
        automatic logic signed [15:0] width, height, side_length_temp;

        // Compute min_x
        min_x = $signed(x0);
        if ($signed(x1) < min_x) min_x = $signed(x1);
        if ($signed(x2) < min_x) min_x = $signed(x2);
        if ($signed(x3) < min_x) min_x = $signed(x3);

        // Compute max_x
        max_x = $signed(x0);
        if ($signed(x1) > max_x) max_x = $signed(x1);
        if ($signed(x2) > max_x) max_x = $signed(x2);
        if ($signed(x3) > max_x) max_x = $signed(x3);

        // Compute min_y
        min_y = $signed(y0);
        if ($signed(y1) < min_y) min_y = $signed(y1);
        if ($signed(y2) < min_y) min_y = $signed(y2);
        if ($signed(y3) < min_y) min_y = $signed(y3);

        // Compute max_y
        max_y = $signed(y0);
        if ($signed(y1) > max_y) max_y = $signed(y1);
        if ($signed(y2) > max_y) max_y = $signed(y2);
        if ($signed(y3) > max_y) max_y = $signed(y3);

        width = max_x - min_x;
        height = max_y - min_y;
        side_length_temp = (width > height) ? width : height;
        side_length <= { {8{side_length_temp[15]}}, side_length_temp[15:8], side_length_temp[7:0], 8'b0 };
        computing <= 1;
        counter <= 0;
      end else if (computing) begin
        if (counter < 4'd9) begin
          counter <= counter + 1;
        end else begin
          done <= 1;
          computing <= 0;
        end
      end
    end
  end
endmodule