module md5_single_block (
  input clk,
  input rst_n,
  input start,
  input [511:0] blk,
  output reg [127:0] hash,
  output reg done
);

  localparam [31:0] T[0:63] = '{
    32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee, 32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
    32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be, 32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
    32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa, 32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
    32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed, 32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
    32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c, 32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
    32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05, 32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
    32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039, 32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
    32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1, 32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391
  };

  localparam [7:0] s[0:63] = '{
    8'd7, 8'd12, 8'd17, 8'd22, 8'd7, 8'd12, 8'd17, 8'd22,
    8'd7, 8'd12, 8'd17, 8'd22, 8'd7, 8'd12, 8'd17, 8'd22,
    8'd5, 8'd9, 8'd14, 8'd20, 8'd5, 8'd9, 8'd14, 8'd20,
    8'd5, 8'd9, 8'd14, 8'd20, 8'd5, 8'd9, 8'd14, 8'd20,
    8'd4, 8'd11, 8'd16, 8'd23, 8'd4, 8'd11, 8'd16, 8'd23,
    8'd4, 8'd11, 8'd16, 8'd23, 8'd4, 8'd11, 8'd16, 8'd23,
    8'd6, 8'd10, 8'd15, 8'd21, 8'd6, 8'd10, 8'd15, 8'd21,
    8'd6, 8'd10, 8'd15, 8'd21, 8'd6, 8'd10, 8'd15, 8'd21
  };

  localparam [4:0] k[0:63] = '{
    5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7,
    5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15,
    5'd1, 5'd6, 5'd11, 5'd0, 5'd5, 5'd10, 5'd15, 5'd4,
    5'd9, 5'd14, 5'd3, 5'd8, 5'd13, 5'd2, 5'd7, 5'd12,
    5'd5, 5'd8, 5'd11, 5'd14, 5'd1, 5'd4, 5'd7, 5'd10,
    5'd13, 5'd0, 5'd3, 5'd6, 5'd9, 5'd12, 5'd15, 5'd2,
    5'd0, 5'd7, 5'd14, 5'd5, 5'd12, 5'd3, 5'd10, 5'd1,
    5'd8, 5'd15, 5'd6, 5'd13, 5'd4, 5'd11, 5'd2, 5'd9
  };

  reg [5:0] round;
  reg [31:0] M [0:15];
  reg [31:0] a, b, c, d;
  reg [31:0] a0, b0, c0, d0;
  reg processing;

  function [31:0] F;
    input [31:0] B, C, D;
    F = (B & C) | ((~B) & D);
  endfunction

  function [31:0] G;
    input [31:0] B, C, D;
    G = (B & D) | (C & (~D));
  endfunction

  function [31:0] H;
    input [31:0] B, C, D;
    H = B ^ C ^ D;
  endfunction

  function [31:0] I;
    input [31:0] B, C, D;
    I = C ^ (B | (~D));
  endfunction

  function [31:0] rol;
    input [31:0] val;
    input [7:0] shift;
    rol = (val << shift) | (val >> (32 - shift));
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 32'h67452301;
      b <= 32'hefcdab89;
      c <= 32'h98badcfe;
      d <= 32'h10325476;
      done <= 0;
      processing <= 0;
      round <= 0;
    end
    else begin
      if (done) done <= 1;  // Remain high until reset
      else if (start) begin
        a0 <= a;
        b0 <= b;
        c0 <= c;
        d0 <= d;
        M[15] <= blk[31:0];     M[14] <= blk[63:32];
        M[13] <= blk[95:64];    M[12] <= blk[127:96];
        M[11] <= blk[159:128];  M[10] <= blk[191:160];
        M[9]  <= blk[223:192];  M[8]  <= blk[255:224];
        M[7]  <= blk[287:256];  M[6]  <= blk[319:288];
        M[5]  <= blk[351:320];  M[4]  <= blk[383:352];
        M[3]  <= blk[415:384];  M[2]  <= blk[447:416];
        M[1]  <= blk[479:448];  M[0]  <= blk[511:480];
        processing <= 1;
        round <= 0;
      end
      else if (processing) begin
        if (round < 64) begin
          case (round[5:4])
            2'b00: a <= b + rol(a + F(b, c, d) + M[k[round]] + T[round], s[round]);
            2'b01: a <= b + rol(a + G(b, c, d) + M[k[round]] + T[round], s[round]);
            2'b10: a <= b + rol(a + H(b, c, d) + M[k[round]] + T[round], s[round]);
            2'b11: a <= b + rol(a + I(b, c, d) + M[k[round]] + T[round], s[round]);
          endcase
          {a, d, c, b} <= {d, c, b, a};
          round <= round + 1;
        end

        if (round == 63) begin
          hash <= {a0 + a, b0 + b, c0 + c, d0 + d};
          done <= 1;
          processing <= 0;
        end
      end
    end
  end
endmodule