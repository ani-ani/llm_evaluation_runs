module special_number_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] n_bin,
  input [3:0] k,
  output reg [31:0] count,
  output reg done
);

  localparam MOD = 32'd1000000007;
  localparam [15:0] binom [0:16][0:16] = '{
    '{16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h2, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h3, 16'h3, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h4, 16'h6, 16'h4, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h5, 16'h10,16'h10,16'h5, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h6, 16'h15,16'h20,16'h15,16'h6, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h7, 16'h21,16'h35,16'h35,16'h21,16'h7, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h8, 16'h28,16'h56,16'h70,16'h56,16'h28,16'h8, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h9, 16'h36,16'h84,16'h126,16'h126,16'h84,16'h36,16'h9, 16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h10,16'h45,16'h120,16'h210,16'h252,16'h210,16'h120,16'h45,16'h10,16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h11,16'h55,16'h165,16'h330,16'h462,16'h462,16'h330,16'h165,16'h55,16'h11,16'h1, 16'h0, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h12,16'h66,16'h220,16'h495,16'h792,16'h924,16'h792,16'h495,16'h220,16'h66,16'h12,16'h1, 16'h0, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h13,16'h78,16'h286,16'h715,16'h1287,16'h1716,16'h1716,16'h1287,16'h715,16'h286,16'h78,16'h13,16'h1, 16'h0, 16'h0, 16'h0},
    '{16'h1, 16'h14,16'h91,16'h364,16'h1001,16'h2002,16'h3003,16'h3432,16'h3003,16'h2002,16'h1001,16'h364,16'h91,16'h14,16'h1, 16'h0, 16'h0},
    '{16'h1, 16'h15,16'h105,16'h455,16'h1365,16'h3003,16'h5005,16'h6435,16'h6435,16'h5005,16'h3003,16'h1365,16'h455,16'h105,16'h15,16'h1, 16'h0},
    '{16'h1, 16'h16,16'h120,16'h560,16'h1820,16'h4368,16'h8008,16'h11440,16'h12870,16'h11440,16'h8008,16'h4368,16'h1820,16'h560,16'h120,16'h16,16'h1}
  };

  localparam [3:0] g_vals [1:16] = '{0,0,1,0,1,1,2,0,1,1,2,1,2,2,1,0};

  reg [4:0] cycle;
  reg [15:0] n_latch;
  reg [3:0] k_latch;
  wire [1:16] qual_p;
  genvar p;
  generate
    for (p=1; p<=16; p=p+1) begin
      assign qual_p[p] = (p==1 && k_latch==0) || (p>1 && (1 + g_vals[p]) == k_latch);
    end
  endgenerate

  reg [31:0] cnt_array [1:16];
  reg [4:0] bits_so_far [1:16];
  reg [4:0] remaining [1:16];
  reg [31:0] final_sum;

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      count <= 0;
      final_sum <= 0;
      cycle <= 0;
      for (i=1; i<=16; i=i+1) begin
        cnt_array[i] <= 0;
        bits_so_far[i] <= 0;
        remaining[i] <= 16;
      end
    end else begin
      if (start) begin
        n_latch <= n_bin;
        k_latch <= k;
        cycle <= 1;
        done <= 0;
        for (i=1; i<=16; i=i+1) begin
          cnt_array[i] <= 0;
          bits_so_far[i] <= 0;
          remaining[i] <= 16;
        end
      end else if (cycle >=1 && cycle <=20) begin
        if (cycle <= 16) begin
          integer j;
          for (j=1; j<=16; j=j+1) begin
            if (qual_p[j]) begin
              if (n_latch[16 - cycle] === 1'b1) begin
                if (bits_so_far[j] <= j && (remaining[j]-1) >= (j - bits_so_far[j])) begin
                  cnt_array[j] <= (cnt_array[j] + binom[remaining[j]-1][j - bits_so_far[j]]) % MOD;
                end
                bits_so_far[j] <= bits_so_far[j] + 1'b1;
              end
              remaining[j] <= remaining[j] - 1'b1;
            end
          end
        end else if (cycle == 17) begin
          final_sum <= 0;
          for (i=1; i<=16; i=i+1) begin
            if (qual_p[i] && bits_so_far[i] == i) begin
              cnt_array[i] <= (cnt_array[i] + 1) % MOD;
            end
          end
        end else if (cycle == 18) begin
          for (i=1; i<=16; i=i+1) begin
            if (qual_p[i]) begin
              final_sum <= (final_sum + cnt_array[i]) % MOD;
            end
          end
        end else if (cycle == 19) begin
          count <= final_sum;
          done <= 1;
        end else if (cycle ==20) begin
          done <= 0;
        end
        cycle <= cycle + 1;
      end else begin
        done <= 0;
      end
    end
  end
endmodule