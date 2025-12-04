module dice_expectation (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [3:0] n,
  output reg [31:0] result,
  output reg done
);

  localparam IDLE = 3'd0;
  localparam RECIP1 = 3'd1;
  localparam RECIP2 = 3'd2;
  localparam LOAD_I = 3'd3;
  localparam TERM_INIT = 3'd4;
  localparam EXP_LOOP = 3'd5;
  localparam ACCUMULATE = 3'd6;
  localparam FINISH = 3'd7;

  reg [2:0] state;
  reg [2:0] m_captured;
  reg [3:0] n_captured;
  reg [31:0] recip_m;
  reg [3:0] i;
  reg [31:0] sum;
  reg [31:0] power_reg;
  reg [31:0] term_i_reg;
  reg [3:0] exponent_count;

  wire [31:0] recip_val = (m_captured == 0) ? 32'd0 : (32'd65536 / m_captured);
  wire [63:0] mult_term = {32'd0, i} * recip_m;
  wire [63:0] mult_power = power_reg * term_i_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      sum <= 0;
      result <= 0;
      i <= 4'd0;
      recip_m <= 32'd0;
      m_captured <= 3'd0;
      n_captured <= 4'd0;
      power_reg <= 32'd0;
      term_i_reg <= 32'd0;
      exponent_count <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            m_captured <= m;
            n_captured <= n;
            sum <= 0;
            state <= RECIP1;
          end
        end

        RECIP1: begin
          recip_m <= recip_val;
          state <= RECIP2;
        end

        RECIP2: begin
          i <= 4'd1;
          state <= LOAD_I;
        end

        LOAD_I: begin
          if (i < m_captured) begin
            state <= TERM_INIT;
          end else begin
            state <= FINISH;
          end
        end

        TERM_INIT: begin
          term_i_reg <= mult_term[31:0];
          power_reg <= mult_term[31:0];
          if (n_captured == 4'd1) begin
            state <= ACCUMULATE;
          end else begin
            exponent_count <= 4'd1;
            state <= EXP_LOOP;
          end
        end

        EXP_LOOP: begin
          power_reg <= mult_power[47:16];
          if (exponent_count == (n_captured - 1)) begin
            state <= ACCUMULATE;
          end else begin
            exponent_count <= exponent_count + 1;
          end
        end

        ACCUMULATE: begin
          sum <= sum + power_reg;
          i <= i + 1;
          state <= LOAD_I;
        end

        FINISH: begin
          result <= (m_captured << 16) - sum;
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule