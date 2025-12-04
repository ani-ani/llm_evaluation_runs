module permutation_cycle_generator(input [3:0] N, input [3:0] A, input [3:0] B, output valid, output [31:0] perm);
  logic found;
  logic [3:0] x_found;
  logic [3:0] y_found;
  logic [3:0] perm_array [0:7];

  always_comb begin
    found = 1'b0;
    x_found = 0;
    y_found = 0;

    for (int x = 0; x <= 8; x = x + 1) begin
      logic [7:0] xA = x * A;
      if (xA <= N) begin
        logic [7:0] remainder = N - xA;
        if (remainder % B == 0) begin
          logic [7:0] y_temp = remainder / B;
          if (!found) begin
            found = 1'b1;
            x_found = x;
            y_found = y_temp;
          end
        end
      end
    end

    integer current_num = 1;
    integer idx = 0;
    for (int i = 0; i < 8; i = i + 1) perm_array[i] = 4'd0;

    if (found) begin
      for (int i = 0; i < x_found; i = i + 1) begin
        for (int j = 0; j < A; j = j + 1) begin
          perm_array[idx] = (j < A-1) ? (current_num + j + 1) : current_num;
          idx = idx + 1;
        end
        current_num = current_num + A;
      end

      for (int i = 0; i < y_found; i = i + 1) begin
        for (int j = 0; j < B; j = j + 1) begin
          perm_array[idx] = (j < B-1) ? (current_num + j + 1) : current_num;
          idx = idx + 1;
        end
        current_num = current_num + B;
      end
    end
  end

  assign valid = found;
  assign perm = {perm_array[7], perm_array[6], perm_array[5], perm_array[4],
                perm_array[3], perm_array[2], perm_array[1], perm_array[0]};
endmodule