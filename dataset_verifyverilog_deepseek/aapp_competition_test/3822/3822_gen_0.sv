module pupil_transport_time(input clk, input rst_n, input start, input [15:0] n, input [15:0] l, input [15:0] v1, input [15:0] v2, input [15:0] k, output reg [31:0] time_q16, output reg done);
  reg [3:0] iteration;
  reg [31:0] low_reg, high_reg;
  reg [15:0] groups_count;
  reg [15:0] n_latch, l_latch, v1_latch, v2_latch, k_latch;
  reg busy, cmp_result;
  wire [31:0] mid = (low_reg + high_reg) >> 1;
  wire [31:0] v1_Q = {v1_latch, 16'b0};
  wire [31:0] v2_Q = {v2_latch, 16'b0};
  wire [31:0] l_Q = {l_latch, 16'b0};
  wire [31:0] v1_mid = ({32'd0, v1_Q} * {32'd0, mid})[63:32];
  wire [31:0] y_numerator = l_Q > v1_mid ? l_Q - v1_mid : 32'd0;
  wire [31:0] y_denominator = v2_Q - v1_Q;
  wire [31:0] y = (y_denominator != 0) ? ( (y_numerator << 16) / y_denominator ) : 32'd0;
  wire [31:0] v1_plus_v2 = v1_Q + v2_Q;
  wire [31:0] pikap = (v1_plus_v2 != 0) ? ( (v1_mid << 16) / v1_plus_v2 ) : 32'd0;
  wire [31:0] term1 = pikap * ((groups_count > 0) ? (groups_count - 1) : 0);
  wire [31:0] term2 = y * groups_count;
  wire [31:0] sum = term1 + term2;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      time_q16 <= 0;
      done <= 0;
      busy <= 0;
      iteration <= 0;
      low_reg <= 0;
      high_reg <= 0;
      groups_count <= 0;
    end else begin
      if (start && !busy) begin
        n_latch <= n;
        l_latch <= l;
        v1_latch <= v1;
        v2_latch <= v2;
        k_latch <= k;
        groups_count <= (n == 0) ? 0 : (n + k - 1) / k;
        low_reg <= 0;
        high_reg <= ( {l, 16'b0} << 16 ) / {v1, 16'b0};
        iteration <= 0;
        busy <= 1;
        done <= 0;
      end else if (busy) begin
        iteration <= iteration + 1;
        if (cmp_result) high_reg <= mid;
        else low_reg <= mid;
        if (iteration == 4'd15) begin
          time_q16 <= high_reg;
          done <= 1;
          busy <= 0;
        end
      end else if (!start) done <= 0;
    end
  end
  always @(*) begin
    cmp_result = (sum <= mid);
  end
endmodule