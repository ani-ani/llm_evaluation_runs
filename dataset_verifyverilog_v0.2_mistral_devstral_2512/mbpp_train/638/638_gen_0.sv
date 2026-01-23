module wind_chill (
  input clk,
  input rst_n,
  input start,
  input [15:0] v,
  input [15:0] t,
  output reg [15:0] result,
  output reg done
);

  // Constants in Q16.16 format
  localparam [31:0] C13_12 = 32'h000D1F48; // 13.12
  localparam [31:0] C0_6215 = 32'h00009EB8; // 0.6215
  localparam [32:0] C11_37 = 33'h000B5E64; // 11.37 (33 bits for multiplication)
  localparam [31:0] C0_3965 = 32'h0000659F; // 0.3965

  // State encoding
  typedef enum logic [3:0] {
    IDLE,
    CALC1,
    CALC2,
    CALC3,
    CALC4,
    DONE
  } state_t;

  state_t state, next_state;

  // Intermediate results
  reg [31:0] term1; // 0.6215 * t
  reg [31:0] v_pow; // v^0.16 from LUT
  reg [31:0] term2; // 11.37 * v_pow
  reg [31:0] term3; // 0.3965 * t * v_pow
  reg [31:0] sum;   // 13.12 + term1 - term2 + term3

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   next_state = start ? CALC1 : IDLE;
      CALC1:  next_state = CALC2;
      CALC2:  next_state = CALC3;
      CALC3:  next_state = CALC4;
      CALC4:  next_state = DONE;
      DONE:   next_state = start ? CALC1 : IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      term1 <= 32'h0;
      v_pow <= 32'h0;
      term2 <= 32'h0;
      term3 <= 32'h0;
      sum <= 32'h0;
      result <= 16'h0;
    end else begin
      case (state)
        CALC1: begin
          // Compute 0.6215 * t (Q16.16 * Q16.16 = Q32.32, keep upper 32 bits)
          term1 <= (C0_6215 * {t, 16'h0}) >>> 16;
          // Load v^0.16 from LUT
          v_pow <= lut_v_pow(v);
        end
        CALC2: begin
          // Compute 11.37 * v_pow (Q16.16 * Q16.16 = Q32.32, keep upper 32 bits)
          term2 <= (C11_37 * {v_pow, 16'h0}) >>> 16;
          // Compute 0.3965 * t * v_pow
          // First multiply 0.3965 * t (Q16.16 * Q16.16 = Q32.32)
          reg [31:0] temp = (C0_3965 * {t, 16'h0}) >>> 16;
          // Then multiply by v_pow (Q16.16 * Q16.16 = Q32.32, keep upper 32 bits)
          term3 <= (temp * {v_pow, 16'h0}) >>> 16;
        end
        CALC3: begin
          // Sum all terms: 13.12 + term1 - term2 + term3
          sum <= C13_12 + term1 - term2 + term3;
        end
        CALC4: begin
          // Round to nearest integer (Q16.16 to integer)
          // Add 0x8000 (0.5 in Q16.16) and take upper 16 bits
          result <= (sum + 16'h8000) >>> 16;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Lookup table for v^0.16 in Q16.16 format
  function [31:0] lut_v_pow(input [15:0] v);
    case (v)
      0:   lut_v_pow = 32'h00000000; // 0^0.16 = 0
      1:   lut_v_pow = 32'h0000F6A6; // ~0.96
      2:   lut_v_pow = 32'h0000F999; // ~0.98
      3:   lut_v_pow = 32'h0000FB8C; // ~0.99
      4:   lut_v_pow = 32'h0000FD1A; // ~0.995
      5:   lut_v_pow = 32'h0000FE66; // ~0.998
      6:   lut_v_pow = 32'h0000FF47; // ~1.001
      7:   lut_v_pow = 32'h00010000; // ~1.003
      8:   lut_v_pow = 32'h000100A0; // ~1.005
      9:   lut_v_pow = 32'h0001012C; // ~1.007
      10:  lut_v_pow = 32'h000101A8; // ~1.009
      11:  lut_v_pow = 32'h00010216; // ~1.010
      12:  lut_v_pow = 32'h00010278; // ~1.012
      13:  lut_v_pow = 32'h000102D0; // ~1.013
      14:  lut_v_pow = 32'h00010320; // ~1.014
      15:  lut_v_pow = 32'h00010368; // ~1.015
      16:  lut_v_pow = 32'h000103AC; // ~1.016
      17:  lut_v_pow = 32'h000103EC; // ~1.017
      18:  lut_v_pow = 32'h00010428; // ~1.018
      19:  lut_v_pow = 32'h00010460; // ~1.019
      20:  lut_v_pow = 32'h00010494; // ~1.020
      21:  lut_v_pow = 32'h000104C4; // ~1.021
      22:  lut_v_pow = 32'h000104F0; // ~1.022
      23:  lut_v_pow = 32'h00010518; // ~1.023
      24:  lut_v_pow = 32'h0001053C; // ~1.024
      25:  lut_v_pow = 32'h0001055C; // ~1.025
      26:  lut_v_pow = 32'h00010578; // ~1.026
      27:  lut_v_pow = 32'h00010590; // ~1.027
      28:  lut_v_pow = 32'h000105A4; // ~1.028
      29:  lut_v_pow = 32'h000105B4; // ~1.029
      30:  lut_v_pow = 32'h000105C0; // ~1.030
      31:  lut_v_pow = 32'h000105CC; // ~1.031
      32:  lut_v_pow = 32'h000105D4; // ~1.032
      33:  lut_v_pow = 32'h000105DC; // ~1.033
      34:  lut_v_pow = 32'h000105E0; // ~1.034
      35:  lut_v_pow = 32'h000105E4; // ~1.035
      36:  lut_v_pow = 32'h000105E8; // ~1.036
      37:  lut_v_pow = 32'h000105EC; // ~1.037
      38:  lut_v_pow = 32'h000105F0; // ~1.038
      39:  lut_v_pow = 32'h000105F4; // ~1.039
      40:  lut_v_pow = 32'h000105F8; // ~1.040
      41:  lut_v_pow = 32'h000105FC; // ~1.041
      42:  lut_v_pow = 32'h00010600; // ~1.042
      43:  lut_v_pow = 32'h00010604; // ~1.043
      44:  lut_v_pow = 32'h00010608; // ~1.044
      45:  lut_v_pow = 32'h0001060C; // ~1.045
      46:  lut_v_pow = 32'h00010610; // ~1.046
      47:  lut_v_pow = 32'h00010614; // ~1.047
      48:  lut_v_pow = 32'h00010618; // ~1.048
      49:  lut_v_pow = 32'h0001061C; // ~1.049
      50:  lut_v_pow = 32'h00010620; // ~1.050
      51:  lut_v_pow = 32'h00010624; // ~1.051
      52:  lut_v_pow = 32'h00010628; // ~1.052
      53:  lut_v_pow = 32'h0001062C; // ~1.053
      54:  lut_v_pow = 32'h00010630; // ~1.054
      55:  lut_v_pow = 32'h00010634; // ~1.055
      56:  lut_v_pow = 32'h00010638; // ~1.056
      57:  lut_v_pow = 32'h0001063C; // ~1.057
      58:  lut_v_pow = 32'h00010640; // ~1.058
      59:  lut_v_pow = 32'h00010644; // ~1.059
      60:  lut_v_pow = 32'h00010648; // ~1.060
      61:  lut_v_pow = 32'h0001064C; // ~1.061
      62:  lut_v_pow = 32'h00010650; // ~1.062
      63:  lut_v_pow = 32'h00010654; // ~1.063
      64:  lut_v_pow = 32'h00010658; // ~1.064
      65:  lut_v_pow = 32'h0001065C; // ~1.065
      66:  lut_v_pow = 32'h00010660; // ~1.066
      67:  lut_v_pow = 32'h00010664; // ~1.067
      68:  lut_v_pow = 32'h00010668; // ~1.068
      69:  lut_v_pow = 32'h0001066C; // ~1.069
      70:  lut_v_pow = 32'h00010670; // ~1.070
      71:  lut_v_pow = 32'h00010674; // ~1.071
      72:  lut_v_pow = 32'h00010678; // ~1.072
      73:  lut_v_pow = 32'h0001067C; // ~1.073
      74:  lut_v_pow = 32'h00010680; // ~1.074
      75:  lut_v_pow = 32'h00010684; // ~1.075
      76:  lut_v_pow = 32'h00010688; // ~1.076
      77:  lut_v_pow = 32'h0001068C; // ~1.077
      78:  lut_v_pow = 32'h00010690; // ~1.078
      79:  lut_v_pow = 32'h00010694; // ~1.079
      80:  lut_v_pow = 32'h00010698; // ~1.080
      81:  lut_v_pow = 32'h0001069C; // ~1.081
      82:  lut_v_pow = 32'h000106A0; // ~1.082
      83:  lut_v_pow = 32'h000106A4; // ~1.083
      84:  lut_v_pow = 32'h000106A8; // ~1.084
      85:  lut_v_pow = 32'h000106AC; // ~1.085
      86:  lut_v_pow = 32'h000106B0; // ~1.086
      87:  lut_v_pow = 32'h000106B4; // ~1.087
      88:  lut_v_pow = 32'h000106B8; // ~1.088
      89:  lut_v_pow = 32'h000106BC; // ~1.089
      90:  lut_v_pow = 32'h000106C0; // ~1.090
      91:  lut_v_pow = 32'h000106C4; // ~1.091
      92:  lut_v_pow = 32'h000106C8; // ~1.092
      93:  lut_v_pow = 32'h000106CC; // ~1.093
      94:  lut_v_pow = 32'h000106D0; // ~1.094
      95:  lut_v_pow = 32'h000106D4; // ~1.095
      96:  lut_v_pow = 32'h000106D8; // ~1.096
      97:  lut_v_pow = 32'h000106DC; // ~1.097
      98:  lut_v_pow = 32'h000106E0; // ~1.098
      99:  lut_v_pow = 32'h000106E4; // ~1.099
      100: lut_v_pow = 32'h000106E8; // ~1.100
      101: lut_v_pow = 32'h000106EC; // ~1.101
      102: lut_v_pow = 32'h000106F0; // ~1.102
      103: lut_v_pow = 32'h000106F4; // ~1.103
      104: lut_v_pow = 32'h000106F8; // ~1.104
      105: lut_v_pow = 32'h000106FC; // ~1.105
      106: lut_v_pow = 32'h00010700; // ~1.106
      107: lut_v_pow = 32'h00010704; // ~1.107
      108: lut_v_pow = 32'h00010708; // ~1.108
      109: lut_v_pow = 32'h0001070C; // ~1.109
      110: lut_v_pow = 32'h00010710; // ~1.110
      111: lut_v_pow = 32'h00010714; // ~1.111
      112: lut_v_pow = 32'h00010718; // ~1.112
      113: lut_v_pow = 32'h0001071C; // ~1.113
      114: lut_v_pow = 32'h00010720; // ~1.114
      115: lut_v_pow = 32'h00010724; // ~1.115
      116: lut_v_pow = 32'h00010728; // ~1.116
      117: lut_v_pow = 32'h0001072C; // ~1.117
      118: lut_v_pow = 32'h00010730; // ~1.118
      119: lut_v_pow = 32'h00010734; // ~1.119
      120: lut_v_pow = 32'h00010738; // ~1.120
      default: lut_v_pow = 32'h00010738; // Clamp to max
    endcase
  endfunction

endmodule