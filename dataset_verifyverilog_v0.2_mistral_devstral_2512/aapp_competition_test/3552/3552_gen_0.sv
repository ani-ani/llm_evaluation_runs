module GnomeDamageOptimizer(
  input clk,
  input rst_n,
  input start,
  input [63:0] n,
  input [63:0] m,
  input [63:0] k,
  output reg [63:0] max_damage,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    DONE
  } state_t;

  state_t state;
  reg [63:0] low;
  reg [63:0] high;
  reg [63:0] mid;
  reg [63:0] mid_plus_1;
  reg [63:0] damage_mid;
  reg [63:0] damage_mid_plus_1;

  // Calculate R = ceil(n/x)
  function [63:0] calc_R(input [63:0] x);
    if (x == 0) begin
      return 0;
    end
    return (n + x - 1) / x;
  endfunction

  // Calculate damage for a given x
  function [63:0] calc_damage(input [63:0] x);
    reg [63:0] R;
    reg [63:0] base_damage;
    reg [63:0] reduction;
    reg [63:0] bolt_penalty;
    reg [63:0] remaining;
    reg [63:0] i;

    R = calc_R(x);
    base_damage = n * R;
    reduction = (x * R * (R - 1)) / 2;

    // Bolt penalty calculation
    remaining = n;
    bolt_penalty = 0;
    for (i = 0; i < m - 1; i = i + 1) begin
      if (remaining > x) begin
        remaining = remaining - x;
      end else begin
        remaining = 0;
      end
      bolt_penalty = bolt_penalty + remaining;
    end

    return base_damage - reduction - k * bolt_penalty;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      low <= 0;
      high <= 0;
      mid <= 0;
      mid_plus_1 <= 0;
      damage_mid <= 0;
      damage_mid_plus_1 <= 0;
      max_damage <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SEARCH;
            low <= 1;
            high <= n / m;
            if (high < low) begin
              high <= low;
            end
          end
        end
        SEARCH: begin
          if (low >= high) begin
            max_damage <= calc_damage(low);
            state <= DONE;
            done <= 1;
          end else begin
            mid <= (low + high) / 2;
            mid_plus_1 <= mid + 1;
            damage_mid <= calc_damage(mid);
            damage_mid_plus_1 <= calc_damage(mid_plus_1);

            if (damage_mid < damage_mid_plus_1) begin
              low <= mid_plus_1;
            end else begin
              high <= mid;
            end
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule