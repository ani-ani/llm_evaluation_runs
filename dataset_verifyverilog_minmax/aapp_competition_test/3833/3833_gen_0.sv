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

parameter IDLE   = 3'd0;
parameter COUNT  = 3'd1;
parameter PREFIX = 3'd2;
parameter BUILD  = 3'd3;
parameter DONE   = 4'd4;

reg [2:0] state, next_state;
reg [15:0] result;
reg [15:0] mask_s, mask_t;
reg [4:0] s_len_reg, t_len_reg;
reg [7:0] zeros_s_reg, ones_s_reg, zeros_t_reg, ones_t_reg, zerosTotal_reg, onesTotal_reg;
reg [4:0] L_reg, suffix_len_reg, zeros_needed_per_extra_reg, ones_needed_per_extra_reg, extra_copies_reg;
reg [4:0] out_stage, in_idx, extra_cnt, out_pos, bits_remaining;
reg [4:0] remainingZeros_reg, remainingOnes_reg;
reg [4:0] total_output_bits_reg;
reg [4:0] lps [15:0];
reg [7:0] max_by_zero, max_by_one;
reg [7:0] ones_s_temp, ones_t_temp;

// Combinational logic for next_state and ready
always_comb begin
  next_state = state;
  ready = 1'b0;
  case (state)
    IDLE:   if (start) next_state = COUNT;
    COUNT:  next_state = PREFIX;
    PREFIX: next_state = BUILD;
    BUILD:  if (bits_remaining == 5'd0) next_state = DONE;
    DONE: begin
      ready = 1'b1;
      if (!start) next_state = IDLE;
    end
    default: next_state = IDLE;
  endcase
end

// Sequential state and data logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    result <= 16'd0;
    ready <= 1'b0;
    s_len_reg <= 5'd0;
    t_len_reg <= 5'd0;
    zeros_s_reg <= 8'd0;
    ones_s_reg <= 8'd0;
    zeros_t_reg <= 8'd0;
    ones_t_reg <= 8'd0;
    zerosTotal_reg <= 8'd0;
    onesTotal_reg <= 8'd0;
    L_reg <= 5'd0;
    suffix_len_reg <= 5'd0;
    zeros_needed_per_extra_reg <= 5'd0;
    ones_needed_per_extra_reg <= 5'd0;
    extra_copies_reg <= 5'd0;
    out_stage <= 5'd0;
    in_idx <= 5'd0;
    extra_cnt <= 5'd0;
    out_pos <= 5'd0;
    bits_remaining <= 5'd0;
    remainingZeros_reg <= 5'd0;
    remainingOnes_reg <= 5'd0;
    total_output_bits_reg <= 5'd0;
    max_by_zero <= 8'd0;
    max_by_one <= 8'd0;
  end else begin
    state <= next_state;
    case (state)
      IDLE: begin
        result <= 16'd0;
      end
      COUNT: begin
        // Reset result
        result <= 16'd0;
        s_len_reg <= s_len;
        t_len_reg <= t_len;
        // Build masks
        mask_s <= 16'hffff << (5'd16 - s_len);
        mask_t <= 16'hffff << (5'd16 - t_len);
        // Count ones using $countones
        ones_s_temp = $countones(s_in & mask_s);
        zeros_s_reg <= s_len - ones_s_temp;
        ones_s_reg <= ones_s_temp;
        ones_t_temp = $countones(t_in & mask_t);
        zeros_t_reg <= t_len - ones_t_temp;
        ones_t_reg <= ones_t_temp;
        zerosTotal_reg <= (s_len - ones_s_temp) + (t_len - ones_t_temp);
        onesTotal_reg <= ones_s_temp + ones_t_temp;
      end
      PREFIX: begin
        // Compute prefix function (KMP) for t_in
        lps[0] <= 5'd0;
        for (int i = 1; i < t_len_reg; i++) begin
          int j;
          if (i == 1) j = 5'd0;
          else j = lps[i-1];
          while (j > 0 && t_in[15 - i] != t_in[15 - j]) begin
            j = lps[j-1];
          end
          if (t_in[15 - i] == t_in[15 - j]) begin
            j = j + 1;
          end
          lps[i] <= j;
        end
        // Overlap length
        L_reg <= lps[t_len_reg-1];
        // Count zeros in prefix of length L_reg
        reg [4:0] zeros_prefix, ones_prefix;
        zeros_prefix = 5'd0;
        ones_prefix = 5'd0;
        for (int i = 0; i < L_reg; i++) begin
          if (t_in[15 - i] == 1'b0) zeros_prefix = zeros_prefix + 1;
          else ones_prefix = ones_prefix + 1;
        end
        zeros_needed_per_extra_reg <= zeros_t_reg - zeros_prefix;
        ones_needed_per_extra_reg <= ones_t_reg - ones_prefix;
        suffix_len_reg <= t_len_reg - L_reg;
        // Remaining after first full copy
        remainingZeros_reg <= zerosTotal_reg - zeros_t_reg;
        remainingOnes_reg <= onesTotal_reg - ones_t_reg;
        // Compute extra copies possible
        if (suffix_len_reg == 5'd0) begin
          extra_copies_reg <= 5'd0;
        end else begin
          if (zeros_needed_per_extra_reg == 5'd0) max_by_zero <= 8'd255;
          else max_by_zero <= remainingZeros_reg / zeros_needed_per_extra_reg;
          if (ones_needed_per_extra_reg == 5'd0) max_by_one <= 8'd255;
          else max_by_one <= remainingOnes_reg / ones_needed_per_extra_reg;
          extra_copies_reg <= (max_by_zero < max_by_one) ? max_by_zero : max_by_one;
        end
        // Update remaining zeros/ones after extra copies
        remainingZeros_reg <= remainingZeros_reg - (extra_copies_reg * zeros_needed_per_extra_reg);
        remainingOnes_reg <= remainingOnes_reg - (extra_copies_reg * ones_needed_per_extra_reg);
        // Total output bits
        total_output_bits_reg <= t_len_reg + (extra_copies_reg * suffix_len_reg) + remainingZeros_reg + remainingOnes_reg;
        // Initialize BUILD control variables
        out_stage <= 5'd0;
        in_idx <= 5'd0;
        extra_cnt <= extra_copies_reg;
        out_pos <= 5'd15;
        bits_remaining <= total_output_bits_reg;
      end
      BUILD: begin
        if (bits_remaining > 0) begin
          reg [4:0] new_stage, new_idx, new_extra_cnt, new_out_pos, new_bits_remaining, new_remainingZeros, new_remainingOnes;
          reg new_bit;
          new_stage = out_stage;
          new_idx = in_idx;
          new_extra_cnt = extra_cnt;
          new_remainingZeros = remainingZeros_reg;
          new_remainingOnes = remainingOnes_reg;
          new_out_pos = out_pos;
          new_bits_remaining = bits_remaining - 1;
          new_bit = 1'b0;
          case (out_stage)
            0: begin // full t_in
              new_bit = t_in[15 - in_idx];
              if (in_idx == t_len_reg - 1) begin
                if (extra_copies_reg > 0) begin
                  new_stage = 1;
                  new_extra_cnt = extra_copies_reg;
                  new_idx = 0;
                end else begin
                  new_stage = 2;
                  new_idx = 0;
                end
              end else begin
                new_idx = in_idx + 1;
              end
            end
            1: begin // extra copies (suffix)
              new_bit = t_in[15 - (L_reg + in_idx)];
              if (in_idx == suffix_len_reg - 1) begin
                if (extra_cnt > 1) begin
                  new_extra_cnt = extra_cnt - 1;
                  new_idx = 0;
                end else begin
                  new_stage = 2;
                  new_idx = 0;
                end
              end else begin
                new_idx = in_idx + 1;
              end
            end
            2: begin // zeros
              new_bit = 1'b0;
              if (remainingZeros_reg > 0) begin
                new_remainingZeros = remainingZeros_reg - 1;
              end else begin
                new_stage = 3;
              end
            end
            3: begin // ones
              new_bit = 1'b1;
              if (remainingOnes_reg > 0) begin
                new_remainingOnes = remainingOnes_reg - 1;
              end
            end
          endcase
          // Place bit in result
          result[out_pos] = new_bit;
          // Update control registers
          out_stage <= new_stage;
          in_idx <= new_idx;
          extra_cnt <= new_extra_cnt;
          remainingZeros_reg <= new_remainingZeros;
          remainingOnes_reg <= new_remainingOnes;
          out_pos <= new_out_pos - 1;
          bits_remaining <= new_bits_remaining;
        end
      end
      DONE: begin
        // result already stable, ready handled by combinational logic
      end
      default: ;
    endcase
  end
end

endmodule
