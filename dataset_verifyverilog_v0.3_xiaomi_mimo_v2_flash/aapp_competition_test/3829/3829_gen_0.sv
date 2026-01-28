module expected_max (
  input clk,
  input rst_n,
  input start,
  input [7:0] m,
  input [7:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] INIT = 3'b001;
  localparam [2:0] COMPUTE_POWER = 3'b010;
  localparam [2:0] POWER_LOOP = 3'b011;
  localparam [2:0] ADD_SUM = 3'b100;
  localparam [2:0] FINISH = 3'b101;

  reg [2:0] state, next_state;
  reg [7:0] i, next_i;
  reg [7:0] j, next_j;
  reg [31:0] power, next_power;
  reg [31:0] sum, next_sum;
  reg [31:0] ratio_reg, next_ratio_reg;
  wire [63:0] product;
  wire [31:0] new_power;

  // Fixed-point constant: 1.0 in Q16.16
  localparam [31:0] ONE = 32'h00010000;

  // Combinational calculations
  assign product = power * ratio_reg;
  assign new_power = product[47:16];  // Q16.16 result of power * ratio_reg

  always @(*) begin
    // Default assignments
    next_state = state;
    next_i = i;
    next_j = j;
    next_power = power;
    next_sum = sum;
    next_ratio_reg = ratio_reg;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        next_i = 8'd1;
        next_sum = 32'd0;
        next_state = COMPUTE_POWER;
      end

      COMPUTE_POWER: begin
        next_ratio_reg = (i * 32'd65536) / m;
        next_power = ONE;
        next_j = 8'd0;
        next_state = POWER_LOOP;
      end

      POWER_LOOP: begin
        if (j < n) begin
          next_power = new_power;
          next_j = j + 8'd1;
        end else begin
          next_state = ADD_SUM;
        end
      end

      ADD_SUM: begin
        next_sum = sum + power;
        if (i < m - 8'd1) begin
          next_i = i + 8'd1;
          next_state = COMPUTE_POWER;
        end else begin
          next_state = FINISH;
        end
      end

      FINISH: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 8'd0;
      j <= 8'd0;
      power <= 32'd0;
      sum <= 32'd0;
      ratio_reg <= 32'd0;
      result <= 32'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      i <= next_i;
      j <= next_j;
      power <= next_power;
      sum <= next_sum;
      ratio_reg <= next_ratio_reg;
      done <= 1'b0;

      if (state == FINISH) begin
        result <= (m * 32'd65536) - sum;
        done <= 1'b1;
      end
    end
  end

endmodule