module break_scheduler(
  input clk,
  input rst_n,
  input start,
  input [3:0] T,
  input [2:0] N,
  input [4:0][3:0] breaks,
  output reg [4:0][3:0] start_times,
  output reg done
);

  reg [3:0] T_reg;
  reg [2:0] N_reg;
  reg [4:0][3:0] breaks_reg;
  reg [3:0] counter;
  wire [4:0][3:0] computed_starts;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      T_reg <= 4'd0;
      N_reg <= 3'd0;
      breaks_reg <= 20'd0;
      counter <= 4'd0;
      done <= 1'b0;
    end else begin
      if (start && counter == 0) begin
        T_reg <= T;
        N_reg <= N;
        breaks_reg <= breaks;
      end

      if (counter < 10) begin
        counter <= (start || counter > 0) ? counter + 1 : 4'd0;
      end

      done <= (counter >= 10);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      start_times <= 20'd0;
    end else if (counter >= 10) begin
      start_times <= computed_starts;
    end
  end

  // Start time computation logic
  assign computed_starts = calc_start_times(T_reg, N_reg, breaks_reg);

  function automatic [4:0][3:0] calc_start_times(input [3:0] T_val, input [2:0] N_val, input [4:0][3:0] brks);
    reg [3:0] l0, l1;
    reg [3:0] result [5];

    l0 = 4'd0;
    l1 = 4'd0;
    for (int i=0; i<5; i++) result[i] = 4'd0;

    if (N_val > 0) begin
      result[0] = (brks[0] <= T_val) ? 4'd0 : T_val - brks[0];
      l0 = result[0] + brks[0];
    end

    if (N_val > 1) begin
      result[1] = (brks[1] <= T_val) ? 4'd0 : T_val - brks[1];
      l1 = result[1] + brks[1];
    end

    if (N_val > 2) begin
      if (l0 <= l1) begin
        result[2] = (l0 <= T_val - brks[2]) ? l0 : T_val - brks[2];
        l0 = result[2] + brks[2];
      end else begin
        result[2] = (l1 <= T_val - brks[2]) ? l1 : T_val - brks[2];
        l1 = result[2] + brks[2];
      end
    end

    if (N_val > 3) begin
      if (l0 <= l1) begin
        result[3] = (l0 <= T_val - brks[3]) ? l0 : T_val - brks[3];
        l0 = result[3] + brks[3];
      end else begin
        result[3] = (l1 <= T_val - brks[3]) ? l1 : T_val - brks[3];
        l1 = result[3] + brks[3];
      end
    end

    if (N_val > 4) begin
      if (l0 <= l1) begin
        result[4] = (l0 <= T_val - brks[4]) ? l0 : T_val - brks[4];
        l0 = result[4] + brks[4];
      end else begin
        result[4] = (l1 <= T_val - brks[4]) ? l1 : T_val - brks[4];
        l1 = result[4] + brks[4];
      end
    end

    return {result[4], result[3], result[2], result[1], result[0]};
  endfunction
endmodule