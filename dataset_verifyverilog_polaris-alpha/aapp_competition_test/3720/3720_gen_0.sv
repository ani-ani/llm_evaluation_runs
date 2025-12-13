module powers_game(
  input  [7:0] n,  // Input number (1 <= n <= 255)
  output        winner  // 1=Vasya wins, 0=Petya wins
);

  // Precomputed nimber array (index 0..29 used)
  // arr = [0,1,2,1,4,3,2,1,5,6,2,1,8,7,5,9,8,7,3,4,7,4,2,1,10,9,3,6,11,12]
  function automatic [7:0] arr_val(input [5:0] idx);
    case (idx)
      6'd0:  arr_val = 8'd0;
      6'd1:  arr_val = 8'd1;
      6'd2:  arr_val = 8'd2;
      6'd3:  arr_val = 8'd1;
      6'd4:  arr_val = 8'd4;
      6'd5:  arr_val = 8'd3;
      6'd6:  arr_val = 8'd2;
      6'd7:  arr_val = 8'd1;
      6'd8:  arr_val = 8'd5;
      6'd9:  arr_val = 8'd6;
      6'd10: arr_val = 8'd2;
      6'd11: arr_val = 8'd1;
      6'd12: arr_val = 8'd8;
      6'd13: arr_val = 8'd7;
      6'd14: arr_val = 8'd5;
      6'd15: arr_val = 8'd9;
      6'd16: arr_val = 8'd8;
      6'd17: arr_val = 8'd7;
      6'd18: arr_val = 8'd3;
      6'd19: arr_val = 8'd4;
      6'd20: arr_val = 8'd7;
      6'd21: arr_val = 8'd4;
      6'd22: arr_val = 8'd2;
      6'd23: arr_val = 8'd1;
      6'd24: arr_val = 8'd10;
      6'd25: arr_val = 8'd9;
      6'd26: arr_val = 8'd3;
      6'd27: arr_val = 8'd6;
      6'd28: arr_val = 8'd11;
      6'd29: arr_val = 8'd12;
      default: arr_val = 8'd0;
    endcase
  endfunction

  // Integer square root (floor) for 8-bit input
  function automatic [7:0] isqrt(input [7:0] x);
    integer k;
    reg [15:0] sq;
    begin
      isqrt = 0;
      for (k = 1; k <= 16; k = k + 1) begin
        sq = k * k;
        if (sq <= x)
          isqrt = k[7:0];
      end
    end
  endfunction

  // Check if x is a perfect power >= 2^2 (i.e., a^b with a>=2, b>=2)
  function automatic is_perfect_power(input [7:0] x);
    integer a, b;
    integer val;
    begin
      if (x < 4) begin
        is_perfect_power = 0;
      end else begin
        is_perfect_power = 0;
        for (a = 2; a <= 15 && !is_perfect_power; a = a + 1) begin
          val = a * a;
          b = 2;
          while (val <= x && !is_perfect_power) begin
            if (val == x) begin
              is_perfect_power = 1;
            end else begin
              b = b + 1;
              val = val * a;
            end
          end
        end
      end
    end
  endfunction

  // Compute floor(log2(x)) for x>=1
  function automatic [5:0] log2_floor(input [7:0] x);
    integer k;
    begin
      log2_floor = 0;
      for (k = 0; k < 8; k = k + 1) begin
        if (x[7-k]) begin
          log2_floor = 7-k;
          disable for_loop_end;
        end
      end
      for_loop_end: ;
    end
  endfunction

  // Highest power p such that base^p <= n (p>=1)
  function automatic [5:0] max_power(input [7:0] base, input [7:0] limit);
    integer p;
    integer val;
    begin
      p = 0;
      val = 1;
      while (val * base <= limit && (val * base) > 0) begin
        val = val * base;
        p = p + 1;
      end
      if (p == 0)
        max_power = 1; // at least 1, though for base>=2 and limit>=1, p>=1
      else
        max_power = p[5:0];
    end
  endfunction

  // Main combinational logic
  reg [7:0] ans_reg;
  reg [15:0] s_reg;
  reg [7:0] root_n;
  integer i;
  reg [5:0] lg2_n;
  reg [5:0] p_i;
  reg [7:0] final_ans;

  always @* begin
    if (n == 0) begin
      // Out-of-spec, treat as Petya wins
      final_ans = 0;
    end else begin
      lg2_n = log2_floor(n);
      ans_reg = arr_val(lg2_n);
      s_reg = lg2_n;
      root_n = isqrt(n);

      // i from 3 to sqrt(n)
      for (i = 3; i <= root_n; i = i + 1) begin
        if (!is_perfect_power(i[7:0])) begin
          p_i = max_power(i[7:0], n);
          ans_reg = ans_reg ^ arr_val(p_i);
          s_reg  = s_reg + p_i;
        end
      end

      // ans ^= ((n - s) % 2)
      final_ans = ans_reg ^ ((n - s_reg[7:0]) & 8'd1);
    end
  end

  assign winner = (final_ans != 0);

endmodule