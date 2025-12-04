module bandwidth_allocator(
  input clk,
  input rst_n,
  input start,
  input [31:0] t_fixed,
  input [31:0] a0, a1, a2, a3,
  input [31:0] b0, b1, b2, b3,
  input [31:0] d0, d1, d2, d3,
  output reg [31:0] x0, x1, x2, x3,
  output reg done
);

  typedef enum {
    IDLE,
    CALC_FAIR,
    CLAMP,
    DISTRIBUTE,
    VERIFY,
    DONE_ST
  } state_t;

  state_t current_state, next_state;
  reg [5:0] cycle_count;
  reg [31:0] sum_d, sum_d_nonconstrained;
  reg [63:0] d_t_product [3:0];
  reg [31:0] y [3:0];
  reg [31:0] T;
  reg [31:0] remaining;
  reg [3:0] iter_count;
  reg [31:0] x_temp [3:0];
  reg [31:0] nonconstrained_d [3:0];
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      cycle_count <= 0;
      iter_count <= 0;
      {x0, x1, x2, x3} <= '{0,0,0,0};
    end else begin
      current_state <= next_state;
      cycle_count <= (current_state == IDLE) ? 0 : cycle_count + 1;

      case (current_state)
        CALC_FAIR: begin
          sum_d <= d0 + d1 + d2 + d3;
          d_t_product[0] <= d0 * t_fixed;
          d_t_product[1] <= d1 * t_fixed;
          d_t_product[2] <= d2 * t_fixed;
          d_t_product[3] <= d3 * t_fixed;
        end

        CLAMP: begin
          for (i=0; i<4; i=i+1) begin
            y[i] <= (sum_d != 0) ? (d_t_product[i] / sum_d) : 0;
          end
        end

        DISTRIBUTE: begin
          sum_d_nonconstrained <= 0;
          nonconstrained_d[0] <= (x_temp[0] < b0) ? d0 : 0;
          nonconstrained_d[1] <= (x_temp[1] < b1) ? d1 : 0;
          nonconstrained_d[2] <= (x_temp[2] < b2) ? d2 : 0;
          nonconstrained_d[3] <= (x_temp[3] < b3) ? d3 : 0;
          sum_d_nonconstrained <= nonconstrained_d[0] + nonconstrained_d[1] + nonconstrained_d[2] + nonconstrained_d[3];
        end

        VERIFY: begin
          x0 <= x_temp[0];
          x1 <= x_temp[1];
          x2 <= x_temp[2];
          x3 <= x_temp[3];
        end

        DONE_ST: begin
          done <= 1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start)
          next_state = CALC_FAIR;
      end

      CALC_FAIR: next_state = CLAMP;

      CLAMP: begin
        for (i=0; i<4; i=i+1) begin
          x_temp[i] = (y[i] < a[i]) ? a[i] :
                     (y[i] > b[i]) ? b[i] :
                     y[i];
        end
        T = x_temp[0] + x_temp[1] + x_temp[2] + x_temp[3];
        remaining = t_fixed - T;
        if (remaining == 0)
          next_state = DONE_ST;
        else
          next_state = DISTRIBUTE;
      end

      DISTRIBUTE: begin
        if (sum_d_nonconstrained != 0) begin
          for (i=0; i<4; i=i+1) begin
            reg [63:0] alloc_part = (nonconstrained_d[i] * remaining) / sum_d_nonconstrained;
            reg [31:0] alloc = (alloc_part > (b[i] - x_temp[i])) ? (b[i] - x_temp[i]) : alloc_part[31:0];
            x_temp[i] = x_temp[i] + alloc;
          end
        end
        T = x_temp[0] + x_temp[1] + x_temp[2] + x_temp[3];
        remaining = t_fixed - T;
        if (remaining == 0 || iter_count >= 10)
          next_state = VERIFY;
        else begin
          next_state = DISTRIBUTE;
          iter_count = iter_count + 1;
        end
      end

      VERIFY: begin
        next_state = (cycle_count >= 49) ? DONE_ST : DISTRIBUTE;
      end

      DONE_ST: begin
        if (~start)
          next_state = IDLE;
      end
    endcase
  end
endmodule