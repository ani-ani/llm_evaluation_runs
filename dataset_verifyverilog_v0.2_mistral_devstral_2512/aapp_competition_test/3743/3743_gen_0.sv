module aesthetic_path_solver(
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  output reg [31:0] result,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    CHECK_2,
    HANDLE_POW2,
    CHECK_ODD,
    VERIFY_POWER,
    ITERATE,
    DONE
  } state_t;

  state_t state;
  reg [31:0] d;
  reg [31:0] temp_n;
  reg [31:0] sqrt_n;
  reg [31:0] power_check;
  reg is_power;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      d <= 0;
      temp_n <= 0;
      sqrt_n <= 0;
      power_check <= 0;
      is_power <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_2;
            done <= 0;
            result <= 0;
            temp_n <= n;
            sqrt_n <= compute_sqrt(n);
          end
        end

        CHECK_2: begin
          if (n == 1) begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end else if (n[0] == 0) begin
            state <= HANDLE_POW2;
          end else begin
            d <= 3;
            state <= CHECK_ODD;
          end
        end

        HANDLE_POW2: begin
          if (is_power_of_2(n)) begin
            result <= 2;
            done <= 1;
            state <= DONE;
          end else begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end
        end

        CHECK_ODD: begin
          if (d * d > temp_n) begin
            result <= temp_n;
            done <= 1;
            state <= DONE;
          end else if (temp_n % d == 0) begin
            power_check <= temp_n;
            is_power <= 1;
            state <= VERIFY_POWER;
          end else begin
            d <= d + 2;
            state <= ITERATE;
          end
        end

        VERIFY_POWER: begin
          if (is_power) begin
            power_check <= power_check / d;
            if (power_check % d == 0) begin
              if (power_check == 1) begin
                result <= d;
                done <= 1;
                state <= DONE;
              end
            end else begin
              result <= 1;
              done <= 1;
              state <= DONE;
            end
          end else begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end
        end

        ITERATE: begin
          state <= CHECK_ODD;
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

  function [31:0] compute_sqrt(input [31:0] val);
    reg [31:0] sqrt;
    reg [31:0] temp;
    integer i;
    begin
      sqrt = 0;
      temp = 0;
      for (i = 15; i >= 0; i = i - 1) begin
        temp = (temp << 2) + {val[31:30]};
        val = val << 2;
        sqrt = sqrt << 1;
        if (temp >= (sqrt << 1) + 1) begin
          temp = temp - (sqrt << 1) - 1;
          sqrt = sqrt + 1;
        end
      end
      compute_sqrt = sqrt;
    end
  endfunction

  function is_power_of_2(input [31:0] val);
    begin
      is_power_of_2 = (val != 0) && (val & (val - 1)) == 0;
    end
  endfunction

endmodule