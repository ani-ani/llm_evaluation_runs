module function_decomposer(
  input [2:0] n,
  input [2:0] f_1, f_2, f_3, f_4, f_5, f_6, f_7, f_8,
  output valid,
  output [2:0] m,
  output [2:0] g_1, g_2, g_3, g_4, g_5, g_6, g_7, g_8,
  output [2:0] h_1, h_2, h_3, h_4, h_5, h_6, h_7, h_8
);

  reg [2:0] f [1:8];
  reg [2:0] g [1:8];
  reg [2:0] h [1:8];
  reg [2:0] unique [1:8];
  reg [2:0] temp_f [1:8];
  reg [2:0] i, j, k, count, idx;
  reg [7:0] seen;
  reg is_idempotent;

  assign f[1] = f_1;
  assign f[2] = f_2;
  assign f[3] = f_3;
  assign f[4] = f_4;
  assign f[5] = f_5;
  assign f[6] = f_6;
  assign f[7] = f_7;
  assign f[8] = f_8;

  assign g_1 = g[1];
  assign g_2 = g[2];
  assign g_3 = g[3];
  assign g_4 = g[4];
  assign g_5 = g[5];
  assign g_6 = g[6];
  assign g_7 = g[7];
  assign g_8 = g[8];

  assign h_1 = h[1];
  assign h_2 = h[2];
  assign h_3 = h[3];
  assign h_4 = h[4];
  assign h_5 = h[5];
  assign h_6 = h[6];
  assign h_7 = h[7];
  assign h_8 = h[8];

  always @(*) begin
    valid = 0;
    m = 0;
    for (i = 1; i <= 8; i = i + 1) begin
      g[i] = 0;
      h[i] = 0;
    end

    is_idempotent = 1;
    for (i = 1; i <= n; i = i + 1) begin
      temp_f[i] = f[f[i]];
      if (temp_f[i] != f[i]) begin
        is_idempotent = 0;
      end
    end

    if (is_idempotent) begin
      seen = 0;
      count = 0;
      for (i = 1; i <= n; i = i + 1) begin
        if (!(seen[f[i]])) begin
          seen[f[i]] = 1;
          count = count + 1;
          unique[count] = f[i];
        end
      end

      for (i = 1; i <= count; i = i + 1) begin
        for (j = i + 1; j <= count; j = j + 1) begin
          if (unique[i] > unique[j]) begin
            k = unique[i];
            unique[i] = unique[j];
            unique[j] = k;
          end
        end
      end

      for (i = 1; i <= count; i = i + 1) begin
        h[i] = unique[i];
      end

      for (i = 1; i <= n; i = i + 1) begin
        idx = 0;
        for (j = 1; j <= count; j = j + 1) begin
          if (f[i] == h[j]) begin
            idx = j;
          end
        end
        g[i] = idx;
      end

      valid = 1;
      m = count;
    end
  end
endmodule