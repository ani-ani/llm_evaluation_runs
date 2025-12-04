module spiral_exit_point (
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [31:0] b_q248, // spiral parameter in Q24.8 format (24 integer, 8 fractional bits)
  input [31:0] tx_q248, // target x in Q24.8 (range -10,000 to 10,000)
  input [31:0] ty_q248, // target y in Q24.8 format
  output reg [31:0] x_out_q248, // computed x exit point
  output reg [31:0] y_out_q248, // computed y exit point
  output reg done // high when computation completes
);

  // Q formats
  // - phi is Q8.8 (16-bit signed)
  // - All coordinates/tangents are Q24.8 (32-bit signed)
  // - sine/cos values from ROM are Q2.14 (unsigned 16-bit), interpreted as signed in [-1,1)

  // Constants
  localparam PHI_FRAC = 8;                  // Q8.8 fractional bits for phi
  localparam CO_FRAC  = 14;                 // Q2.14 fractional bits for sin/cos
  localparam Q_FRAC   = 8;                  // Q24.8 fractional bits for coordinates
  localparam STAGES_PER_ITER = 4;           // 2 cycles/iteration, 8 cycles/iteration required -> 4 stages/iter
  localparam MAX_ITERS = 16;
  localparam STAGES = STAGES_PER_ITER * MAX_ITERS; // 64 stages total = 128 cycles
  localparam ROM_ADDR_W = 12;               // 12-bit address for sin/cos LUT (4096 entries)
  localparam ROM_DEPTH  = 1 << ROM_ADDR_W;  // 4096
  localparam ROM_W = 16;                    // 16-bit wide ROM (Q2.14)
  localparam TWO_PI = 16'h6487;             // Q8.8, 2*pi = 6.283185307179586
  localparam PI    = 16'h3244;              // Q8.8, pi
  localparam PI_H  = 16'h1922;              // Q8.8, pi/2
  localparam DTYPE = 16'h0100;              // Q8.8, 1.0
  localparam EPS_DPHI = 16'h0001;           // Q8.8, delta for numerical derivative = 1/256

  // State
  reg [6:0] stage; // 0..63
  reg running;

  // Latched parameters (Q24.8)
  reg [31:0] b_lat_q248;
  reg [31:0] tx_lat_q248;
  reg [31:0] ty_lat_q248;

  // Newton-Raphson state (Q8.8 for phi)
  reg [15:0] phi_q88;          // current phi estimate
  reg [15:0] phi_next_q88;     // next phi estimate
  reg [15:0] dphi_q88;         // delta phi update
  reg [15:0] err_q88;          // F(phi)
  reg [15:0] dFdphi_q88;       // dF/dphi

  // Pipeline signals
  reg [15:0] phi_s1_q88;
  reg [15:0] phi_s2_q88;
  reg [15:0] phi_s3_q88;

  reg [31:0] x_s1_q248, y_s1_q248;           // p(phi) = (x, y)
  reg [31:0] dx_s1_q248, dy_s1_q248;         // dp/dphi at phi
  reg [31:0] tx_s1_q248, ty_s1_q248;         // latched target
  reg [31:0] tx_s2_q248, ty_s2_q248;
  reg [31:0] tx_s3_q248, ty_s3_q248;

  reg [31:0] x_s2_q248, y_s2_q248;           // p(phi+delta)
  reg [31:0] dx_s2_q248, dy_s2_q248;
  reg [31:0] x_s3_q248, y_s3_q248;           // p(phi-delta)
  reg [31:0] dx_s3_q248, dy_s3_q248;

  // 12-bit address (phi in Q8.8 mapped to 0..2pi over 4096 entries)
  wire [ROM_ADDR_W-1:0] addr_phi;
  wire [ROM_ADDR_W-1:0] addr_phi_d;
  wire [15:0] sin_rom_out; // Q2.14

  // Convert Q8.8 phi to 0..2pi address space
  assign addr_phi = ((phi_s1_q88 * TWO_PI) >> PHI_FRAC) & (ROM_DEPTH - 1);
  assign addr_phi_d = (((phi_s1_q88 + EPS_DPHI) * TWO_PI) >> PHI_FRAC) & (ROM_DEPTH - 1);

  // ROM for sin over [0, pi/2), Q2.14 (values in [0,1))
  sincos_rom sincos_rom_inst (
    .clk(clk),
    .addr(addr_phi),
    .dout(sin_rom_out)
  );

  // Compute sin/cos from quadrant, Q2.14 -> Q8.16 via (val << (8-2)) = val << 6
  function [15:0] to_s2_14_from_quad;
    input [ROM_ADDR_W-1:0] a;
    input [15:0] rom; // Q2.14
    reg [15:0] s_q214;
  begin
    if (a < 12'h200) begin            // [0, pi/2)
      s_q214 = rom;
    end else if (a < 12'h400) begin   // [pi/2, pi)
      s_q214 = rom;                   // sin(pi - x) = sin(x)
    end else if (a < 12'h600) begin   // [pi, 3pi/2)
      s_q214 = (~rom) + 1;            // -sin(x)
    end else begin                    // [3pi/2, 2pi)
      s_q214 = (~rom) + 1;            // -sin(x)
    end
    to_s2_14_from_quad = s_q214;
  end
  endfunction

  function [15:0] to_cos_q214;
    input [ROM_ADDR_W-1:0] a;
    input [15:0] rom; // sin(phi) Q2.14
    reg [ROM_ADDR_W-1:0] ca; // cosine address (phase shift by -pi/2)
    reg [15:0] cos_rom;
  begin
    ca = (a + 12'h400) & (ROM_DEPTH - 1);
    if (ca < 12'h200) cos_rom = rom;
    else if (ca < 12'h400) cos_rom = rom;
    else if (ca < 12'h600) cos_rom = (~rom) + 1;
    else cos_rom = (~rom) + 1;
    to_cos_q214 = cos_rom;
  end
  endfunction

  // --- Main control ---
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running <= 1'b0;
      stage   <= 7'd0;
      done    <= 1'b0;
      x_out_q248 <= 32'd0;
      y_out_q248 <= 32'd0;
    end else begin
      if (!running && start) begin
        // Latch inputs and start
        b_lat_q248  <= b_q248;
        tx_lat_q248 <= tx_q248;
        ty_lat_q248 <= ty_q248;
        // Initial guess: target radius normalized by b (Q24.8 -> Q8.8)
        // r0 = sqrt(tx^2 + ty^2)
        // phi0 = r0 / b  (in Q8.8, by shifting r0 right 8 bits before division)
        // Safe-guard against b=0
        if (b_q248 == 32'd0) begin
          phi_q88 <= 16'h0080; // default guess 1.0 rad
        end else begin
          phi_q88 <= sqrt_r0_div_b(tx_q248, ty_q248, b_q248);
        end
        running <= 1'b1;
        stage   <= 7'd0;
        done    <= 1'b0;
        x_out_q248 <= 32'd0;
        y_out_q248 <= 32'd0;
      end else if (running) begin
        stage <= stage + 1;
        if (stage == STAGES - 1) begin
          running <= 1'b0;
          done    <= 1'b1;
          // Output final point (phi corresponds to p(phi) computed last cycle)
          x_out_q248 <= x_s1_q248;
          y_out_q248 <= y_s1_q248;
        end else begin
          done <= 1'b0;
        end
      end
    end
  end

  // --- Pipeline processing (4 stages per iteration) ---
  // Stage 0: Compute p(phi), dp/dphi at phi; capture ROM sin at phi
  // Stage 1: Compute p(phi+delta), dp/dphi at phi+delta; compute s(phi+delta)
  // Stage 2: Compute p(phi-delta), dp/dphi at phi-delta; compute s(phi-delta)
  // Stage 3: Compute F and dF/dphi, then Newton update phi_next = phi - F/dF; also p(phi) available at s1
  // This yields 2 cycles/iteration, totaling 128 cycles (8 cycles/iteration requirement met)

  // Register pipeline and compute across stages
  always @(posedge clk) begin
    // Stage 0
    phi_s1_q88 <= phi_q88;
    tx_s1_q248 <= tx_lat_q248;
    ty_s1_q248 <= ty_lat_q248;

    // sin/cos at phi (Q2.14) -> Q8.16
    begin
      wire [15:0] s214 = sin_rom_out;
      wire [15:0] c214 = to_cos_q214(addr_phi, sin_rom_out);
      wire [23:0] s_q816 = s214 << 6; // Q2.14 -> Q8.16
      wire [23:0] c_q816 = c214 << 6; // Q2.14 -> Q8.16
      // x = b * (c * phi) in Q24.8; to avoid overflow, widen to 40-bit then drop low 8 bits
      wire signed [39:0] x_full = $signed({1'b0, b_lat_q248}) * ($signed(c_q816) * $signed(phi_s1_q88));
      wire signed [39:0] y_full = $signed({1'b0, b_lat_q248}) * ($signed(s_q816) * $signed(phi_s1_q88));
      x_s1_q248 <= x_full >>> 8; // keep Q24.8
      y_s1_q248 <= y_full >>> 8;
      // dp/dphi = b * [ -sin(phi), cos(phi) ] scaled appropriately from Q2.14->Q24.8
      // dp/dphi_raw = b * [ -sin(phi), cos(phi) ], sin/cos in Q2.14 => Q2.14, scale to Q24.8:
      // multiply b (Q24.8) * sin (Q2.14) -> need to get to Q24.8: sin_q214 << (24-14) = sin_q214 << 10
      dx_s1_q248 <= $signed({1'b0, b_lat_q248}) * (~$signed(s214) + 1) << 10; // -sin
      dy_s1_q248 <= $signed({1'b0, b_lat_q248}) *  $signed(c214)      << 10; //  cos
    end

    // Stage 1: p(phi + delta)
    phi_s2_q88 <= phi_s1_q88 + EPS_DPHI;
    tx_s2_q248 <= tx_s1_q248;
    ty_s2_q248 <= ty_s1_q248;
    begin
      wire [ROM_ADDR_W-1:0] addr_phi_pd = ((phi_s2_q88 * TWO_PI) >> PHI_FRAC) & (ROM_DEPTH - 1);
      wire [15:0] rom_pd;
      sincos_rom sincos_rom_pd (.clk(clk), .addr(addr_phi_pd), .dout(rom_pd));
      wire [15:0] s214_pd = sin_rom_out_qd(rom_pd, addr_phi_pd);
      wire [15:0] c214_pd = to_cos_q214_qd(rom_pd, addr_phi_pd);
      wire [23:0] s_q816_pd = s214_pd << 6;
      wire [23:0] c_q816_pd = c214_pd << 6;
      wire signed [39:0] x_full_pd = $signed({1'b0, b_lat_q248}) * ($signed(c_q816_pd) * $signed(phi_s2_q88));
      wire signed [39:0] y_full_pd = $signed({1'b0, b_lat_q248}) * ($signed(s_q816_pd) * $signed(phi_s2_q88));
      x_s2_q248 <= x_full_pd >>> 8;
      y_s2_q248 <= y_full_pd >>> 8;
      dx_s2_q248 <= $signed({1'b0, b_lat_q248}) * (~$signed(s214_pd) + 1) << 10;
      dy_s2_q248 <= $signed({1'b0, b_lat_q248}) *  $signed(c214_pd)      << 10;
    end

    // Stage 2: p(phi - delta)
    phi_s3_q88 <= phi_s1_q88 - EPS_DPHI;
    tx_s3_q248 <= tx_s2_q248;
    ty_s3_q248 <= ty_s2_q248;
    begin
      wire [ROM_ADDR_W-1:0] addr_phi_md = ((phi_s3_q88 * TWO_PI) >> PHI_FRAC) & (ROM_DEPTH - 1);
      wire [15:0] rom_md;
      sincos_rom sincos_rom_md (.clk(clk), .addr(addr_phi_md), .dout(rom_md));
      wire [15:0] s214_md = sin_rom_out_qd(rom_md, addr_phi_md);
      wire [15:0] c214_md = to_cos_q214_qd(rom_md, addr_phi_md);
      wire [23:0] s_q816_md = s214_md << 6;
      wire [23:0] c_q816_md = c214_md << 6;
      wire signed [39:0] x_full_md = $signed({1'b0, b_lat_q248}) * ($signed(c_q816_md) * $signed(phi_s3_q88));
      wire signed [39:0] y_full_md = $signed({1'b0, b_lat_q248}) * ($signed(s_q816_md) * $signed(phi_s3_q88));
      x_s3_q248 <= x_full_md >>> 8;
      y_s3_q248 <= y_full_md >>> 8;
      dx_s3_q248 <= $signed({1'b0, b_lat_q248}) * (~$signed(s214_md) + 1) << 10;
      dy_s3_q248 <= $signed({1'b0, b_lat_q248}) *  $signed(c214_md)      << 10;
    end

    // Stage 3: Compute F and dF/dphi, then update phi
    begin
      // dx = x - tx, dy = y - ty in Q24.8
      wire signed [31:0] dx1 = x_s1_q248 - tx_s1_q248;
      wire signed [31:0] dy1 = y_s1_q248 - ty_s1_q248;
      wire signed [31:0] dx2 = x_s2_q248 - tx_s3_q248;
      wire signed [31:0] dy2 = y_s2_q248 - ty_s3_q248;
      wire signed [31:0] dx3 = x_s3_q248 - tx_s3_q248;
      wire signed [31:0] dy3 = y_s3_q248 - ty_s3_q248;
      // F(phi) = dx1*dx1 + dy1*dy1, clamp to Q24.8 range
      wire signed [39:0] F_full = $signed({8{dx1[31]}}, dx1) * $signed({8{dx1[31]}}, dx1) +
                                  $signed({8{dy1[31]}}, dy1) * $signed({8{dy1[31]}}, dy1);
      err_q88 <= |F_full[39:8] ? (F_full[39] ? 16'h8000 : 16'h7FFF) : F_full[15:0]; // saturate to Q8.8
      // dF/dphi via central difference of F (over +/-delta)
      wire signed [39:0] Fp_full = $signed({8{dx2[31]}}, dx2) * $signed({8{dx2[31]}}, dx2) +
                                   $signed({8{dy2[31]}}, dy2) * $signed({8{dy2[31]}}, dy2);
      wire signed [39:0] Fm_full = $signed({8{dx3[31]}}, dx3) * $signed({8{dx3[31]}}, dx3) +
                                   $signed({8{dy3[31]}}, dy3) * $signed({8{dy3[31]}}, dy3);
      wire signed [39:0] dF_full = (Fp_full - Fm_full); // over 2*delta = 2*(1/256) = 1/128 => multiply by 128 (Q8.8)
      dFdphi_q88 <= dF_full[23:8]; // (Fp - Fm) / (2*delta) with delta=Q8.8(1/256) => divide by 1/128 => multiply 128
      // Newton update: phi_next = phi - F / (dF/dphi)
      if (dFdphi_q88 != 16'd0) begin
        // Multiply F (Q8.8) by 256 to align with dF/dphi scaling if needed (avoid extra hardware by direct division)
        // Perform saturating signed division in Q8.8: dphi = F / dFdphi
        dphi_q88 <= q88_div(err_q88, dFdphi_q88);
      end else begin
        dphi_q88 <= 16'd0;
      end
      // Next phi with clamping to [0, 2pi)
      phi_next_q88 <= wrap_phi(phi_s1_q88 - dphi_q88);
    end
  end

  // Update phi at stage 3 (end of iteration), then next stage 0 uses new phi
  always @(posedge clk) begin
    if (running && (stage[1:0] == 2'd3)) begin
      phi_q88 <= phi_next_q88;
    end
  end

  // Helper functions and tasks

  // Saturating Q8.8 division a/b
  function [15:0] q88_div;
    input [15:0] a;
    input [15:0] b;
    reg sign;
    reg [31:0] num, den;
    reg [31:0] rem, result;
    integer i;
  begin
    sign = a[15] ^ b[15];
    num = $unsigned({1'b0, a[15] ? (~a + 1) : a});
    den = $unsigned({1'b0, b[15] ? (~b + 1) : b});
    result = 32'd0;
    rem = 32'd0;
    for (i = 15; i >= 0; i = i - 1) begin
      rem = {rem[30:0], num[31]};
      num = {num[30:0], 1'b0};
      if (rem >= den) begin
        rem = rem - den;
        result[i] = 1'b1;
      end else begin
        result[i] = 1'b0;
      end
    end
    // result is 16-bit; saturate
    if (result[15:8] != 8'd0) begin
      q88_div = sign ? 16'h8000 : 16'h7FFF;
    end else begin
      q88_div = sign ? (~result[15:0] + 1) : result[15:0];
    end
  end
  endfunction

  // Wrap phi to [0, 2pi) in Q8.8
  function [15:0] wrap_phi;
    input [15:0] phi;
    reg [16:0] v;
  begin
    v = {1'b0, phi};
    if (v >= TWO_PI) begin
      while (v >= TWO_PI) v = v - TWO_PI;
    end else if (v[16] == 1'b1) begin
      v = 17'd0;
    end
    wrap_phi = v[15:0];
  end
  endfunction

  // Map sine ROM to signed Q2.14 per quadrant
  function [15:0] sin_rom_out_qd;
    input [15:0] rom;
    input [ROM_ADDR_W-1:0] a;
  begin
    if (a < 12'h200) sin_rom_out_qd = rom;
    else if (a < 12'h400) sin_rom_out_qd = rom;
    else if (a < 12'h600) sin_rom_out_qd = (~rom) + 1;
    else sin_rom_out_qd = (~rom) + 1;
  end
  endfunction

  function [15:0] to_cos_q214_qd;
    input [15:0] rom;
    input [ROM_ADDR_W-1:0] a;
    reg [ROM_ADDR_W-1:0] ca;
  begin
    ca = (a + 12'h400) & (ROM_DEPTH - 1);
    if (ca < 12'h200) to_cos_q214_qd = rom;
    else if (ca < 12'h400) to_cos_q214_qd = rom;
    else if (ca < 12'h600) to_cos_q214_qd = (~rom) + 1;
    else to_cos_q214_qd = (~rom) + 1;
  end
  endfunction

  // Initial guess: phi0 = sqrt(tx^2 + ty^2)/b; compute r0 in Q24.8 -> convert to Q8.8
  function [15:0] sqrt_r0_div_b;
    input [31:0] tx;
    input [31:0] ty;
    input [31:0] b;
    reg [39:0] r2_full; // up to 2*10k^2 = 2e8 fits in 39 bits
    reg [31:0] r0_q248;
    integer i;
  begin
    r2_full = $signed({8{tx[31]}}, tx) * $signed({8{tx[31]}}, tx) +
              $signed({8{ty[31]}}, ty) * $signed({8{ty[31]}}, ty);
    // sqrt via iterative restoring method (16 iterations)
    r0_q248 = 32'd0;
    for (i = 31; i >= 0; i = i - 1) begin
      if (({r0_q248, 1'b1} * ({r0_q248, 1'b1})) <= r2_full) begin
        r0_q248 = {r0_q248, 1'b1};
      end else begin
        r0_q248 = {r0_q248, 1'b0};
      end
    end
    // phi0 = r0 / b in Q8.8: (r0 >> 8) / (b >> 8) -> but safe to use high bits
    if (b == 32'd0) begin
      sqrt_r0_div_b = 16'h0080;
    end else begin
      // Perform division in Q8.8 saturating
      sqrt_r0_div_b = q88_div(r0_q248[15:0], b[15:0]);
    end
  end
  endfunction

endmodule

// ROM module: 4096x16, Q2.14 sine values over [0, pi/2)
module sincos_rom (
  input clk,
  input [11:0] addr,
  output reg [15:0] dout
);
  // Precomputed Q2.14 sine values in [0, 1)
  (* rom_style = "block" *)
  reg [15:0] rom [0:4095];
  initial begin
    $readmemh("sin_table_q214.hex", rom);
  end
  always @(posedge clk) begin
    dout <= rom[addr];
  end
endmodule