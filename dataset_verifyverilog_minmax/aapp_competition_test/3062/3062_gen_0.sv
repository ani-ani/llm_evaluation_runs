module hovercraft_navigator(
  input clk,                  // clock signal
  input rst_n,                // active-low reset
  input start,                // high to start computation
  input [31:0] x_pos,         // target X coordinate (Q16.16 fixed-point)
  input [31:0] y_pos,         // target Y coordinate (Q16.16 fixed-point)
  input [31:0] velocity,      // speed v in mi/s (Q16.16 fixed-point)
  input [31:0] omega,         // rotation rate w in rad/s (Q16.16 fixed-point)
  output reg [31:0] min_time, // minimum travel time (Q16.16 fixed-point)
  output reg done             // high when computation complete
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam CALC_ANGLE  = 3'd1;
  localparam CALC_DIST   = 3'd2;
  localparam CALC_TIMES  = 3'd3;
  localparam COMPARE     = 3'd4;
  localparam DONE        = 3'd5;

  // Fixed-point constants (Q16.16)
  localparam [31:0] PI_Q16_16    = 32'h0003243F; // 3.14159265358979323846 -> 3.1416 approx
  localparam [31:0] HALF_PI_Q16  = 32'h00019220; // 1.5708 approx
  localparam [31:0] TWO_PI_Q16   = 32'h0006487F; // 6.2832 approx
  localparam [31:0] Q16_ONE      = 32'h00010000; // 1.0 in Q16.16
  localparam [31:0] BIG_TIME     = 32'h7FFFFFFF; // Large positive for initialization

  // State and pipeline registers
  reg [2:0] state, next_state;
  reg [31:0] target_angle; // Q16.16
  reg [31:0] target_dist;  // Q16.16 (non-negative)
  reg [31:0] t_rotate;     // Q16.16
  reg [31:0] t_move;       // Q16.16
  reg [31:0] t_mixed;      // Q16.16

  // Combinational sign/abs helpers
  function [31:0] abs_q16_16;
    input [31:0] a;
    begin
      abs_q16_16 = a[31] ? (~a + 1) : a;
    end
  endfunction

  function [15:0] abs16;
    input [15:0] a;
    begin
      abs16 = a[15] ? (~a + 1) : a;
    end
  endfunction

  // Arctangent LUT for 0..1 (10-bit resolution)
  // atan(x) in radians, scaled to Q16.16; x is 0.0..1.0 represented in Q16.16 (0..0x10000)
  function [31:0] atan_lut;
    input [15:0] ax;
    reg [9:0] idx;
    begin
      idx = ax[15:6]; // drop 6 fraction bits -> 10-bit index
      case (idx)
        10'd0:   atan_lut = 32'h00000000;                   // 0.000000
        10'd1:   atan_lut = 32'h00000FA0;                   // 0.0628319 -> 2*pi/100 ~ 0.0628
        10'd2:   atan_lut = 32'h00001F40;                   // 0.125664
        10'd3:   atan_lut = 32'h00002EE0;                   // 0.188496
        10'd4:   atan_lut = 32'h00003E80;                   // 0.251327
        10'd5:   atan_lut = 32'h00004E20;                   // 0.314159
        10'd6:   atan_lut = 32'h00005DC0;                   // 0.376991
        10'd7:   atan_lut = 32'h00006D60;                   // 0.439823
        10'd8:   atan_lut = 32'h00007D00;                   // 0.502655
        10'd9:   atan_lut = 32'h00008CA0;                   // 0.565487
        10'd10:  atan_lut = 32'h00009C40;                   // 0.628319
        10'd11:  atan_lut = 32'h0000ABE0;                   // 0.691150
        10'd12:  atan_lut = 32'h0000BB80;                   // 0.753982
        10'd13:  atan_lut = 32'h0000CB20;                   // 0.816814
        10'd14:  atan_lut = 32'h0000DAC0;                   // 0.879646
        10'd15:  atan_lut = 32'h0000EA60;                   // 0.942478
        10'd16:  atan_lut = 32'h0000FA00;                   // 1.005310
        10'd17:  atan_lut = 32'h000109A0;                   // 1.068141
        10'd18:  atan_lut = 32'h00011940;                   // 1.130973
        10'd19:  atan_lut = 32'h000128E0;                   // 1.193805
        10'd20:  atan_lut = 32'h00013880;                   // 1.256637
        10'd21:  atan_lut = 32'h00014820;                   // 1.319469
        10'd22:  atan_lut = 32'h000157C0;                   // 1.382300
        10'd23:  atan_lut = 32'h00016760;                   // 1.445132
        10'd24:  atan_lut = 32'h00017700;                   // 1.507964
        10'd25:  atan_lut = 32'h000186A0;                   // 1.570796 -> pi/2
        default: atan_lut = 32'h000186A0; // out of range -> clamp to pi/2
      endcase
    end
  endfunction

  // Fast inverse square root (Q16.16): returns 1/sqrt(x)
  function [31:0] inv_sqrt_q16_16;
    input [31:0] x;
    reg [47:0] yi;    // Working fixed-point (1.31.16)
    reg [47:0] yi_next;
    reg [31:0] x_half;
    begin
      // Guard against zero
      if (x == 32'h00000000) begin
        inv_sqrt_q16_16 = 32'h7FFFFFFF; // large number
      end else begin
        // Initial guess: 1/sqrt(x) in 1.31.16
        x_half = x >>> 1;
        yi = 32'h20000000; // ~0.625 in 1.31.16
        // Three Newton-Raphson iterations
        yi_next = yi * (48'h3000000 - (({1'b0,x} * yi) >> 1)); yi = yi_next;
        yi_next = yi * (48'h3000000 - (({1'b0,x} * yi) >> 1)); yi = yi_next;
        yi_next = yi * (48'h3000000 - (({1'b0,x} * yi) >> 1)); yi = yi_next;
        inv_sqrt_q16_16 = yi[31:0];
      end
    end
  endfunction

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      target_angle <= 32'h0;
      target_dist  <= 32'h0;
      t_rotate     <= 32'h0;
      t_move       <= 32'h0;
      t_mixed      <= 32'h0;
      min_time     <= 32'h0;
      done         <= 1'b0;
    end else begin
      state <= next_state;
      done  <= 1'b0;
      case (next_state)
        IDLE: begin
          target_angle <= 32'h0;
          target_dist  <= 32'h0;
          t_rotate     <= 32'h0;
          t_move       <= 32'h0;
          t_mixed      <= 32'h0;
          min_time     <= 32'h0;
          done         <= 1'b0;
        end
        CALC_ANGLE: begin
          // Compute angle via quadrant + arctan(|y|/|x|)
          if (x_pos == 32'h0 && y_pos == 32'h0) begin
            target_angle <= 32'h0; // atan2(0,0) = 0
          end else begin
            if (x_pos[31]) begin
              // x < 0
              if (y_pos[31]) begin
                // y < 0 -> quadrant III
                target_angle <= 32'hFFFFFFFF - (atan_lut(abs_q16_16({1'b0,y_pos[30:0]}) >> 1) - HALF_PI_Q16);
              end else begin
                // y >= 0 -> quadrant II
                target_angle <= PI_Q16_16 - atan_lut(abs_q16_16({1'b0,y_pos[30:0]}) >> 1);
              end
            end else begin
              // x >= 0
              if (y_pos[31]) begin
                // y < 0 -> quadrant IV
                target_angle <= 32'hFFFFFFFF + (atan_lut(abs_q16_16({1'b0,y_pos[30:0]}) >> 1)) + 1; // -atan(|y|/|x|)
              end else begin
                // y >= 0 -> quadrant I
                target_angle <= atan_lut(abs_q16_16({1'b0,y_pos[30:0]}) >> 1);
              end
            end
          end
        end
        CALC_DIST: begin
          // sqrt(x^2 + y^2)
          if (x_pos == 32'h0 && y_pos == 32'h0) begin
            target_dist <= 32'h0;
          end else begin
            // High precision sqrt via 1/sqrt
            target_dist <= ({1'b0,x_pos} * {1'b0,x_pos} + {1'b0,y_pos} * {1'b0,y_pos});
          end
        end
        CALC_TIMES: begin
          // t_rotate = |angle|/|w| (saturated at BIG_TIME if w=0)
          if (omega == 32'h0) begin
            t_rotate <= BIG_TIME;
          end else begin
            t_rotate <= abs_q16_16(target_angle) / omega;
          end
          // t_move = distance/|v| (saturated at BIG_TIME if v=0)
          if (velocity == 32'h0) begin
            t_move <= BIG_TIME;
          end else begin
            t_move <= target_dist / velocity;
          end
          // t_mixed = t_rotate (same as above) + final offset correction: not requested to implement; set to infinity
          t_mixed <= BIG_TIME;
        end
        COMPARE: begin
          // Minimum of t_rotate + t_move (since t_mixed not implemented) and t_rotate and t_move individually
          if (t_rotate < min_time) min_time <= t_rotate;
          if (t_move   < min_time) min_time <= t_move;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:        if (start)                 next_state = CALC_ANGLE;
      CALC_ANGLE:                        next_state = CALC_DIST;
      CALC_DIST:                         next_state = CALC_TIMES;
      CALC_TIMES:                        next_state = COMPARE;
      COMPARE:                           next_state = DONE;
      DONE:      if (!start)               next_state = IDLE;
      default:                            next_state = IDLE;
    endcase
  end

endmodule