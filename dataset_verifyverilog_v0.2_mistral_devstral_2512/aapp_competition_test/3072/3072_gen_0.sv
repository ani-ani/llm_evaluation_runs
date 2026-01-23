module max_perimeter_rectangle (
  input [7:0] grid [0:7],
  output [6:0] max_perimeter
);

  integer i, j, k, l;
  integer current_perimeter;
  integer max_perim = 0;
  integer width, height;
  bit valid;

  always_comb begin
    max_perim = 0;
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        if (grid[i][j] == 0) begin
          for (k = i; k < 8; k = k + 1) begin
            for (l = j; l < 8; l = l + 1) begin
              valid = 1;
              for (width = i; width <= k; width = width + 1) begin
                for (height = j; height <= l; height = height + 1) begin
                  if (grid[width][height] == 1) begin
                    valid = 0;
                  end
                end
              end
              if (valid) begin
                current_perimeter = 2 * ((k - i + 1) + (l - j + 1));
                if (current_perimeter > max_perim) begin
                  max_perim = current_perimeter;
                end
              end
            end
          end
        end
      end
    end
    max_perimeter = max_perim;
  end

endmodule