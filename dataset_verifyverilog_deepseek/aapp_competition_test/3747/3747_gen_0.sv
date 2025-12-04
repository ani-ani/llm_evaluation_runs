module bulbasaur_counter(
  input clk,
  input rst_n,
  input start,
  input [5:0] str_len,
  input [7:0] char_in,
  input valid_char,
  output reg [7:0] bulbasaur_count,
  output reg done
);

  typedef enum logic [2:0] {IDLE, PROCESS, CALC1, CALC2, CALC3} state_t;
  state_t state;

  reg [7:0] B, u, l, b_val, a_val, s, r;
  reg [5:0] remaining;
  reg [7:0] min1, min2, min3, min4, min5;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      B <= 0;
      u <= 0;
      l <= 0;
      b_val <= 0;
      a_val <= 0;
      s <= 0;
      r <= 0;
      remaining <= 0;
      bulbasaur_count <= 0;
      min1 <= 0;
      min2 <= 0;
      min3 <= 0;
      min4 <= 0;
      min5 <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            B <= 0;
            u <= 0;
            l <= 0;
            b_val <= 0;
            a_val <= 0;
            s <= 0;
            r <= 0;
            remaining <= str_len;
          end
        end

        PROCESS: begin
          if (valid_char) begin
            case (char_in)
              8'h42: B <= B + 1;
              8'h75: u <= u + 1;
              8'h6C: l <= l + 1;
              8'h62: b_val <= b_val + 1;
              8'h61: a_val <= a_val + 1;
              8'h73: s <= s + 1;
              8'h72: r <= r + 1;
              default: ;
            endcase
            remaining <= remaining - 1;
          end
          if (remaining == 6'h0) state <= CALC1;
        end

        CALC1: begin
          min1 <= (B < (u >> 1)) ? B : (u >> 1);
          state <= CALC2;
        end

        CALC2: begin
          min2 <= (min1 < l) ? min1 : l;
          min3 <= (min2 < b_val) ? min2 : b_val;
          state <= CALC3;
        end

        CALC3: begin
          min4 <= (min3 < (a_val >> 1)) ? min3 : (a_val >> 1);
          min5 <= (min4 < s) ? min4 : s;
          bulbasaur_count <= (min5 < r) ? min5 : r;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule