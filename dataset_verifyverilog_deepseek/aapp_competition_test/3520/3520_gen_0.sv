module pill_scheduler(
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  input [31:0] c,
  input [31:0] pill1_t,
  input [31:0] pill1_x,
  input [31:0] pill1_y,
  input [31:0] pill2_t,
  input [31:0] pill2_x,
  input [31:0] pill2_y,
  input [31:0] pill3_t,
  input [31:0] pill3_x,
  input [31:0] pill3_y,
  input [31:0] pill4_t,
  input [31:0] pill4_x,
  input [31:0] pill4_y,
  output reg [31:0] max_lifespan,
  output reg done
);

  // State machine
  enum {IDLE, EVAL_PATHS, DONE} state;
  reg [3:0] counter;
  reg [31:0] current_max;

  // Input buffers
  reg [31:0] n_buf, c_buf;
  reg [31:0] t[4], x[4], y[4];

  // Q16.16 multiplication function
  function [31:0] mul_q16_16(input [31:0] a, input [31:0] b);
    reg [63:0] product;
    begin
      product = a * b;
      mul_q16_16 = product[47:16];
    end
  endfunction

  // Q16.16 division function
  function [31:0] div_q16_16(input [31:0] num, input [31:0] den);
    reg [47:0] numerator;
    reg [63:0] quotient;
    begin
      numerator = {num, 16'b0}; // Multiply numerator by 2^16
      quotient = numerator / den;
      div_q16_16 = quotient[31:0];
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      current_max <= 0;
      counter <= 0;
      max_lifespan <= 0;
      {t[0],x[0],y[0],t[1],x[1],y[1],t[2],x[2],y[2],t[3],x[3],y[3]} <= 0;
      n_buf <= 0;
      c_buf <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            // Latch inputs
            n_buf <= n;
            c_buf <= c;
            t[0] <= pill1_t; x[0] <= pill1_x; y[0] <= pill1_y;
            t[1] <= pill2_t; x[1] <= pill2_x; y[1] <= pill2_y;
            t[2] <= pill3_t; x[2] <= pill3_x; y[2] <= pill3_y;
            t[3] <= pill4_t; x[3] <= pill4_x; y[3] <= pill4_y;
            current_max <= n; // Init with no-pill result
            counter <= 4'd0;
            state <= EVAL_PATHS;
          end
        end

        EVAL_PATHS: begin
          if (counter == 0) begin // No pills
            counter <= counter + 1;
          end else begin
            // Calculate L for current combination
            reg [31:0] sum, last_t, last_x, delta;
            integer k, k_idx;
            integer validity;
            sum = 0;
            k = 0;
            last_t = 0;
            last_x = 0;
            validity = 1;
            k_idx = 0;

            // Traverse counter bitmap
            for (integer i = 0; i < 4; i = i + 1) begin
              if (counter[i]) begin
                if (k > 0) begin
                  delta = t[i] - last_t;
                  if (t[i] < last_t) validity = 0; // Invalid sequence
                  sum = sum + mul_q16_16(last_x, delta);
                end
                k = k + 1;
                last_x = x[i];
                last_t = t[i];
                k_idx = i;
              end
            end

            // Compute L if valid sequence
            if (k > 0 && validity) begin
              reg [31:0] numerator, denominator;
              numerator = n_buf + sum - mul_q16_16(c_buf, (k - 1) << 16) - mul_q16_16(last_x, last_t);
              denominator = 32'h10000 - last_x; // 1.0 - x_last (Q16.16)
              current_max <= (div_q16_16(numerator, denominator) > current_max) ?
                             div_q16_16(numerator, denominator) : current_max;
            end
            counter <= counter + 1;
          end
          
          if (counter >= 15) state <= DONE;
        end

        DONE: begin
          max_lifespan <= current_max;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule