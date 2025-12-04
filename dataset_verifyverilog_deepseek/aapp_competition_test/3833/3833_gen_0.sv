module max_substring_rearrange(
  input clk,
  input rst_n,
  input start,
  input [15:0] s_in,
  input [4:0] s_len,
  input [15:0] t_in,
  input [4:0] t_len,
  output reg [15:0] result,
  output reg ready
);

  typedef enum {IDLE, COUNT, PREFIX_CALC, BUILD_RESULT, DONE} state_t;
  state_t current_state, next_state;

  // COUNT variables
  reg [4:0] num_zeros_s;
  reg [4:0] num_ones_s;
  reg [4:0] num_zeros_t;
  reg [4:0] num_ones_t;

  // PREFIX_CALC variables
  reg [3:0] q;
  reg [3:0] k;
  reg [3:0] pi_array [15:0];
  reg [4:0] pi_last;
  reg [4:0] suffix_len;
  reg [15:0] suffix_str;
  reg [4:0] zeros_suffix;
  reg [4:0] ones_suffix;
  reg prefix_calc_done;

  // BUILD_RESULT variables
  reg [4:0] zeros_remaining;
  reg [4:0] ones_remaining;
  reg [3:0] current_bit_ptr;
  reg [15:0] result_temp;
  reg phase1_done;
  reg phase2_done;
  reg phase3_done;

  wire [4:0] t_popcnt;
  wire [4:0] s_popcnt;

  assign t_popcnt = (t_len >= 1) ? (t_in[15] + t_in[14] + t_in[13] + t_in[12]
    + t_in[11] + t_in[10] + t_in[9] + t_in[8]
    + t_in[7] + t_in[6] + t_in[5] + t_in[4]
    + t_in[3] + t_in[2] + t_in[1] + t_in[0]) : 0;

  assign s_popcnt = (s_len >= 1) ? (s_in[15] + s_in[14] + s_in[13] + s_in[12]
    + s_in[11] + s_in[10] + s_in[9] + s_in[8]
    + s_in[7] + s_in[6] + s_in[5] + s_in[4]
    + s_in[3] + s_in[2] + s_in[1] + s_in[0]) : 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      ready <= 0;
      result <= 0;
      next_state <= IDLE;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          ready <= 0;
          result <= 0;
          if (start) next_state <= COUNT;
        end

        COUNT: begin
          num_zeros_t <= t_len - t_popcnt;
          num_ones_t <= t_popcnt;
          num_zeros_s <= s_len - s_popcnt;
          num_ones_s <= s_popcnt;
          next_state <= PREFIX_CALC;
        end

        PREFIX_CALC: begin
          if (!prefix_calc_done) begin
            if (q == 0) begin
              q <= 1;
              k <= 0;
              pi_array <= '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
            end else if (q < t_len) begin
              automatic reg [3:0] tmp_k = k;
              while (tmp_k > 0 && t_in[15 - q] != t_in[15 - tmp_k])
                tmp_k = pi_array[tmp_k-1];
              if (t_in[15 - q] == t_in[15 - tmp_k]) tmp_k++;
              pi_array[q] <= tmp_k;
              k <= tmp_k;
              q <= q + 1;
            end else begin
              pi_last <= pi_array[t_len-1];
              suffix_len <= t_len - pi_last;
              suffix_str <= t_in >> (16 - t_len + pi_last);
              zeros_suffix <= suffix_len - (suffix_str[0] + suffix_str[1] + suffix_str[2] + suffix_str[3]
                + suffix_str[4] + suffix_str[5] + suffix_str[6] + suffix_str[7]
                + suffix_str[8] + suffix_str[9] + suffix_str[10] + suffix_str[11]
                + suffix_str[12] + suffix_str[13] + suffix_str[14] + suffix_str[15]);
              prefix_calc_done <= 1;
              next_state <= BUILD_RESULT;
            end
          end
        end

        BUILD_RESULT: begin
          if (!phase1_done) begin
            if (num_zeros_t <= num_zeros_s && num_ones_t <= num_ones_s && s_len >= t_len) begin
              result_temp <= t_in >> (16 - t_len);
              current_bit_ptr <= t_len;
              zeros_remaining <= num_zeros_s - num_zeros_t;
              ones_remaining <= num_ones_s - num_ones_t;
            end else begin
              zeros_remaining <= num_zeros_s;
              ones_remaining <= num_ones_s;
            end
            phase1_done <= 1;
          end else if (!phase2_done) begin
            if (current_bit_ptr + suffix_len <= s_len && suffix_len != 0
                && zeros_suffix <= zeros_remaining && ones_suffix <= ones_remaining) begin
              result_temp <= (result_temp << suffix_len) | suffix_str;
              current_bit_ptr <= current_bit_ptr + suffix_len;
              zeros_remaining <= zeros_remaining - zeros_suffix;
              ones_remaining <= ones_remaining - ones_suffix;
            end else begin
              phase2_done <= 1;
            end
          end else if (!phase3_done) begin
            integer space = s_len - current_bit_ptr;
            integer z = zeros_remaining;
            integer o = ones_remaining;
            for (integer i=0; i<space; i++) begin
              if (z > 0) begin
                result_temp = result_temp << 1;
                z--;
              end else if (o > 0) begin
                result_temp = (result_temp << 1) | 1'b1;
                o--;
              end else begin
                result_temp = result_temp << 1;
              end
            end
            result <= result_temp << (16 - s_len);
            phase3_done <= 1;
            next_state <= DONE;
          end
        end

        DONE: begin
          ready <= 1;
          if (!start) next_state <= IDLE;
        end
      endcase
      if (current_state != next_state) begin
        phase1_done <= 0;
        phase2_done <= 0;
        phase3_done <= 0;
        prefix_calc_done <= 0;
        q <= 0;
      end
    end
  end

endmodule