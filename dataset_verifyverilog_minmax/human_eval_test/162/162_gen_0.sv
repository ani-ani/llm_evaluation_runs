module md5_single_block (
  input clk,
  input rst_n,
  input start,
  input [511:0] blk,
  output reg [127:0] hash,
  output reg done
);

  // MD5 initial values (little-endian constants)
  localparam A_INIT = 32'h67452301;
  localparam B_INIT = 32'hefcdab89;
  localparam C_INIT = 32'h98badcfe;
  localparam D_INIT = 32'h10325476;

  // T[i] = floor(abs(sin(i+1)) * 2^32) rounded to unsigned 32-bit integer
  localparam [0:63][31:0] T =
  {
    32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
    32'hf57c0faf, 32'h4787c62a, 32'h830d83a8, 32'h265e5a51,
    32'he9b6c7aa, 32'hd62f105d, 32'h02441453, 32'hd8a1e681,
    32'he7d3fbc8, 32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87,
    32'h455a14ed, 32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9,
    32'h8d2a4c8a, 32'hfffa3942, 32'h8771f681, 32'h6d9d6122,
    32'hfde5380c, 32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60,
    32'hbebfbc70, 32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085,
    32'h04881d05, 32'hd9d4d039, 32'h6db2e4b1, 32'h1fa27cf8,
    32'hc4ac5665, 32'hf4292244, 32'h432aff97, 32'hab9423a7,
    32'hfc93a039, 32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d,
    32'h85845dd1, 32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314,
    32'h4e0811a1, 32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb,
    32'heb86d391
  };

  // Left rotation amounts for 64 steps (per MD5 specification)
  localparam [0:63][4:0] S =
  {
    5'd7,  5'd12, 5'd17, 5'd22, 5'd7,  5'd12, 5'd17, 5'd22,
    5'd7,  5'd12, 5'd17, 5'd22, 5'd7,  5'd12, 5'd17, 5'd22,
    5'd5,  5'd9,  5'd14, 5'd20, 5'd5,  5'd9,  5'd14, 5'd20,
    5'd5,  5'd9,   5'd14, 5'd20, 5'd5,  5'd9,  5'd14, 5'd20,
    5'd4,  5'd11, 5'd16, 5'd23, 5'd4,  5'd11, 5'd16, 5'd23,
    5'd4,  5'd11, 5'd16, 5'd23, 5'd4,  5'd11, 5'd16, 5'd23,
    5'd6,  5'd10, 5'd15, 5'd21, 5'd6,  5'd10, 5'd15, 5'd21,
    5'd6,  5'd10, 5'd15, 5'd21, 5'd6,  5'd10, 5'd15, 5'd21
  };

  reg [31:0] a, b, c, d; // current state
  reg [31:0] a_next, b_next, c_next, d_next;
  reg [31:0] x [0:15];   // message schedule
  reg [5:0] cycle;       // 0..63
  reg running;
  reg [31:0] a0, b0, c0, d0; // captured initial state on start

  integer i;
  always @(*) begin
    // schedule message words (512-bit block -> 16 x 32-bit little-endian words)
    for (i = 0; i < 16; i = i + 1) begin
      x[i] = blk[(i*32) +: 32];
    end
  end

  // Non-linear functions per round
  function [31:0] F (input [31:0] x, y, z);
    F = (x & y) | ((~x) & z);
  endfunction
  function [31:0] G (input [31:0] x, y, z);
    G = (x & z) | (y & (~z));
  endfunction
  function [31:0] H (input [31:0] x, y, z);
    H = x ^ y ^ z;
  endfunction
  function [31:0] I (input [31:0] x, y, z);
    I = y ^ (x | (~z));
  endfunction

  // 32-bit left rotate
  function [31:0] rotl (input [31:0] a, input [4:0] n);
    rotl = (a << n) | (a >> (32 - n));
  endfunction

  // Per-cycle combinational update for one MD5 step
  always @(*) begin
    // message index selection per MD5 spec (steps 0..63)
    case (cycle[5:4]) // top two bits of cycle -> round (0..3)
      2'd0: begin
        // Round 1: g = i
        b_next = d;
        d_next = c;
        c_next = b;
        b_next = a;
        a_next = d;
      end
      2'd1: begin
        // Round 2: g = (5*i + 1) mod 16
        case (cycle[3:0])
          4'd0: b_next = 4'd1;
          4'd1: b_next = 4'd6;
          4'd2: b_next = 4'd11;
          4'd3: b_next = 4'd0;
          4'd4: b_next = 4'd5;
          4'd5: b_next = 4'd10;
          4'd6: b_next = 4'd15;
          4'd7: b_next = 4'd4;
          4'd8: b_next = 4'd9;
          4'd9: b_next = 4'd14;
          4'd10: b_next = 4'd3;
          4'd11: b_next = 4'd8;
          4'd12: b_next = 4'd13;
          4'd13: b_next = 4'd2;
          4'd14: b_next = 4'd7;
          4'd15: b_next = 4'd12;
        endcase
        b_next = b_next;
        d_next = c;
        c_next = b;
        b_next = a;
        a_next = d;
      end
      2'd2: begin
        // Round 3: g = (3*i + 5) mod 16
        case (cycle[3:0])
          4'd0: b_next = 4'd5;
          4'd1: b_next = 4'd8;
          4'd2: b_next = 4'd11;
          4'd3: b_next = 4'd14;
          4'd4: b_next = 4'd1;
          4'd5: b_next = 4'd4;
          4'd6: b_next = 4'd7;
          4'd7: b_next = 4'd10;
          4'd8: b_next = 4'd13;
          4'd9: b_next = 4'd0;
          4'd10: b_next = 4'd3;
          4'd11: b_next = 4'd6;
          4'd12: b_next = 4'd9;
          4'd13: b_next = 4'd12;
          4'd14: b_next = 4'd15;
          4'd15: b_next = 4'd2;
        endcase
        d_next = c;
        c_next = b;
        b_next = a;
        a_next = d;
      end
      2'd3: begin
        // Round 4: g = (7*i) mod 16
        case (cycle[3:0])
          4'd0: b_next = 4'd0;
          4'd1: b_next = 4'd7;
          4'd2: b_next = 4'd14;
          4'd3: b_next = 4'd5;
          4'd4: b_next = 4'd12;
          4'd5: b_next = 4'd3;
          4'd6: b_next = 4'd10;
          4'd7: b_next = 4'd1;
          4'd8: b_next = 4'd8;
          4'd9: b_next = 4'd15;
          4'd10: b_next = 4'd6;
          4'd11: b_next = 4'd13;
          4'd12: b_next = 4'd4;
          4'd13: b_next = 4'd11;
          4'd14: b_next = 4'd2;
          4'd15: b_next = 4'd9;
        endcase
        d_next = c;
        c_next = b;
        b_next = a;
        a_next = d;
      end
    endcase

    // compute f and x[g] per round
    if (cycle[5:4] == 2'd0) begin
      a_next = F(b, c, d) + x[cycle[3:0]] + T[cycle] + a;
      a_next = {a_next[31:0], 1'b0} >> 1; // temp to keep width; overwritten below
    end else if (cycle[5:4] == 2'd1) begin
      a_next = G(b, c, d) + x[b_next] + T[cycle] + a;
    end else if (cycle[5:4] == 2'd2) begin
      a_next = H(b, c, d) + x[b_next] + T[cycle] + a;
    end else begin
      a_next = I(b, c, d) + x[b_next] + T[cycle] + a;
    end

    a_next = rotl(a_next, S[cycle]);
    a_next = a_next + b;

    // final swap for this step
    c_next = b;
    d_next = c;
    b_next = a_next;
    a_next = d;
  end

  // sequential behavior
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= A_INIT;
      b <= B_INIT;
      c <= C_INIT;
      d <= D_INIT;
      a0 <= A_INIT;
      b0 <= B_INIT;
      c0 <= C_INIT;
      d0 <= D_INIT;
      cycle <= 6'd0;
      running <= 1'b0;
      done <= 1'b0;
      hash <= 128'd0;
      a_next <= 32'd0;
      b_next <= 32'd0;
      c_next <= 32'd0;
      d_next <= 32'd0;
    end else begin
      // capture start
      if (start) begin
        a0 <= A_INIT;
        b0 <= B_INIT;
        c0 <= C_INIT;
        d0 <= D_INIT;
        a <= A_INIT;
        b <= B_INIT;
        c <= C_INIT;
        d <= D_INIT;
        cycle <= 6'd0;
        running <= 1'b1;
        done <= 1'b0; // will go high after 64 cycles
      end

      // processing pipeline
      if (running) begin
        a <= a_next;
        b <= b_next;
        c <= c_next;
        d <= d_next;

        if (cycle == 6'd63) begin
          // finalize: add initial values
          a <= a_next + a0;
          b <= b_next + b0;
          c <= c_next + c0;
          d <= d_next + d0;
          running <= 1'b0;
          done <= 1'b1;
          cycle <= 6'd0; // keep at 0 while done
        end else begin
          cycle <= cycle + 1;
        end
      end else begin
        // idle: keep state, done remains high until reset
        a <= a;
        b <= b;
        c <= c;
        d <= d;
        cycle <= 6'd0;
      end
    end
  end

  // MD5 digest is little-endian concatenation: A || B || C || D
  always @(*) begin
    hash = {d, c, b, a}; // 128-bit output
  end

endmodule
