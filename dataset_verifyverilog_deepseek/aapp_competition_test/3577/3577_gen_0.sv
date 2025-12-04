module plant_flowers(input clk, rst_n, start, input [7:0] L, input [7:0] R, output reg [4:0] num_flowers, output reg done);
  reg [7:0] L_arr [0:7];
  reg [7:0] R_arr [0:7];
  reg [2:0] cnt;
  reg start_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 3'b0;
      done <= 1'b0;
      start_reg <= 1'b0;
    end else begin
      start_reg <= start;
      done <= 1'b0;
      if (start_reg) begin
        if (cnt < 3'd7) begin
          L_arr[cnt] <= L;
          R_arr[cnt] <= R;
          cnt <= cnt + 1;
        end
        done <= 1'b1;
      end
    end
  end
  always_comb begin
    num_flowers = 5'b0;
ick
    else if (start) begin
      for (int i = 0; i < 8; i++) begin
        if (i < cnt) begin
          if ((L > L_arr[i] && L < R_arr[i]) || (R > L_arr[i] && R < R_arr[i]))
            num_flowers = num_flowers + 5'd1;
        end
      end
    end
  end
endmodule