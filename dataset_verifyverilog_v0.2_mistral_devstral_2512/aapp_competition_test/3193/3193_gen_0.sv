module linear_congruence_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] expr_char_0,
  input [7:0] expr_char_1,
  input [7:0] expr_char_2,
  input [7:0] expr_char_3,
  input [7:0] expr_char_4,
  input [7:0] expr_char_5,
  input [7:0] expr_char_6,
  input [7:0] expr_char_7,
  input [19:0] P,
  input [19:0] M,
  output reg [19:0] result_x,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [19:0] A, B, C;
  reg [19:0] gcd, u, v;
  reg [19:0] temp_A, temp_B;
  reg [19:0] x_solution;
  reg [3:0] parse_index;
  reg [19:0] current_num;
  reg [1:0] current_sign;
  reg [1:0] current_term;
  reg [1:0] op;
  reg [1:0] x_found;
  reg [1:0] num_started;
  reg [1:0] num_ended;
  reg [1:0] eea_state;
  reg [19:0] r0, r1, s0, s1, t0, t1, q;
  reg [19:0] expr_chars [0:7];

  assign expr_chars[0] = expr_char_0;
  assign expr_chars[1] = expr_char_1;
  assign expr_chars[2] = expr_char_2;
  assign expr_chars[3] = expr_char_3;
  assign expr_chars[4] = expr_char_4;
  assign expr_chars[5] = expr_char_5;
  assign expr_chars[6] = expr_char_6;
  assign expr_chars[7] = expr_char_7;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      A <= 0;
      B <= 0;
      C <= 0;
      gcd <= 0;
      u <= 0;
      v <= 0;
      temp_A <= 0;
      temp_B <= 0;
      x_solution <= 0;
      parse_index <= 0;
      current_num <= 0;
      current_sign <= 0;
      current_term <= 0;
      op <= 0;
      x_found <= 0;
      num_started <= 0;
      num_ended <= 0;
      eea_state <= 0;
      r0 <= 0;
      r1 <= 0;
      s0 <= 0;
      s1 <= 0;
      t0 <= 0;
      t1 <= 0;
      q <= 0;
      done <= 0;
      error <= 0;
      result_x <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PARSE;
            parse_index <= 0;
            current_num <= 0;
            current_sign <= 0;
            current_term <= 0;
            op <= 0;
            x_found <= 0;
            num_started <= 0;
            num_ended <= 0;
            A <= 0;
            B <= 0;
            done <= 0;
            error <= 0;
          end
        end
        PARSE: begin
          if (parse_index < 8) begin
            if (expr_chars[parse_index] == 8'b0) begin
              parse_index <= parse_index + 1;
            end else begin
              if (expr_chars[parse_index] == "+" || expr_chars[parse_index] == "-") begin
                if (num_started) begin
                  if (current_term == 0) begin
                    if (x_found) begin
                      temp_A <= current_num;
                    end else begin
                      temp_B <= current_num;
                    end
                  end else begin
                    if (x_found) begin
                      temp_B <= current_num;
                    end else begin
                      temp_A <= current_num;
                    end
                  end
                  num_started <= 0;
                  num_ended <= 0;
                  current_num <= 0;
                  current_sign <= (expr_chars[parse_index] == "-") ? 1 : 0;
                  current_term <= current_term + 1;
                end else begin
                  current_sign <= (expr_chars[parse_index] == "-") ? 1 : 0;
                end
                op <= expr_chars[parse_index] == "+" ? 0 : 1;
              end else if (expr_chars[parse_index] == "x") begin
                x_found <= 1;
                if (!num_started) begin
                  current_num <= 1;
                end
                num_started <= 1;
              end else if (expr_chars[parse_index] >= "0" && expr_chars[parse_index] <= "9") begin
                num_started <= 1;
                current_num <= current_num * 10 + (expr_chars[parse_index] - "0");
              end else if (expr_chars[parse_index] == "*" || expr_chars[parse_index] == "(" || expr_chars[parse_index] == ")") begin
                // Ignore these characters for simplicity
              end
              parse_index <= parse_index + 1;
            end
          end else begin
            if (num_started) begin
              if (current_term == 0) begin
                if (x_found) begin
                  temp_A <= current_num;
                end else begin
                  temp_B <= current_num;
                end
              end else begin
                if (x_found) begin
                  temp_B <= current_num;
                end else begin
                  temp_A <= current_num;
                end
              end
            end
            if (current_sign) begin
              if (current_term == 0) begin
                if (x_found) begin
                  temp_A <= -temp_A;
                end else begin
                  temp_B <= -temp_B;
                end
              end else begin
                if (x_found) begin
                  temp_B <= -temp_B;
                end else begin
                  temp_A <= -temp_A;
                end
              end
            end
            A <= temp_A;
            B <= temp_B;
            state <= COMPUTE;
            eea_state <= 0;
            r0 <= M;
            r1 <= A;
            s0 <= 0;
            s1 <= 1;
            t0 <= 1;
            t1 <= 0;
          end
        end
        COMPUTE: begin
          if (eea_state == 0) begin
            C <= (P - B) % M;
            if (C < 0) begin
              C <= C + M;
            end
            eea_state <= 1;
          end else if (eea_state == 1) begin
            if (r1 == 0) begin
              if (r0 == 1) begin
                u <= s0;
                v <= t0;
                gcd <= r0;
                eea_state <= 2;
              end else begin
                error <= 1;
                state <= DONE;
              end
            end else begin
              q <= r0 / r1;
              r0 <= r0 - q * r1;
              s0 <= s0 - q * s1;
              t0 <= t0 - q * t1;
              r0 <= r1;
              r1 <= r0 - q * r1;
              s0 <= s1;
              s1 <= s0 - q * s1;
              t0 <= t1;
              t1 <= t0 - q * t1;
            end
          end else if (eea_state == 2) begin
            if (C % gcd == 0) begin
              x_solution <= (C * u) % M;
              if (x_solution < 0) begin
                x_solution <= x_solution + M;
              end
              result_x <= x_solution;
              state <= DONE;
              done <= 1;
            end else begin
              error <= 1;
              state <= DONE;
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