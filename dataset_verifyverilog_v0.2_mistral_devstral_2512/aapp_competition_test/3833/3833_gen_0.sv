module schedule_optimizer (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [5:0] s_length,
  input [5:0] t_length,
  input valid_in,
  output reg [7:0] char_out,
  output reg valid_out,
  output reg done
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    INPUT_S,
    INPUT_T,
    COMPUTE_PREFIX,
    FIND_OVERLAP,
    ASSEMBLE_OUTPUT,
    DONE
  } state_t;
  state_t current_state, next_state;

  // Internal buffers and counters
  reg [7:0] s_buf [0:15];
  reg [7:0] t_buf [0:15];
  reg [5:0] zeros_s, ones_s, zeros_t, ones_t;
  reg [5:0] pi [0:15];
  reg [5:0] overlap_len, repeat_zeros, repeat_ones;
  reg [5:0] out_index, repeat_count, remaining_zeros, remaining_ones;
  reg [5:0] s_index, t_index, prefix_index;
  reg [5:0] temp_len;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INPUT_S;
      end
      INPUT_S: begin
        if (s_index == s_length - 1 && valid_in) next_state = INPUT_T;
      end
      INPUT_T: begin
        if (t_index == t_length - 1 && valid_in) next_state = COMPUTE_PREFIX;
      end
      COMPUTE_PREFIX: begin
        if (prefix_index == t_length) next_state = FIND_OVERLAP;
      end
      FIND_OVERLAP: begin
        next_state = ASSEMBLE_OUTPUT;
      end
      ASSEMBLE_OUTPUT: begin
        if (out_index == (t_length + (repeat_count * (t_length - overlap_len)) + remaining_zeros + remaining_ones - 1)) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // State machine actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      s_index <= 0;
      t_index <= 0;
      prefix_index <= 0;
      out_index <= 0;
      zeros_s <= 0;
      ones_s <= 0;
      zeros_t <= 0;
      ones_t <= 0;
      overlap_len <= 0;
      repeat_zeros <= 0;
      repeat_ones <= 0;
      repeat_count <= 0;
      remaining_zeros <= 0;
      remaining_ones <= 0;
      done <= 0;
      valid_out <= 0;
      char_out <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          valid_out <= 0;
        end
        INPUT_S: begin
          if (valid_in) begin
            s_buf[s_index] <= char_in;
            if (char_in == "0") zeros_s <= zeros_s + 1;
            else if (char_in == "1") ones_s <= ones_s + 1;
            s_index <= s_index + 1;
          end
        end
        INPUT_T: begin
          if (valid_in) begin
            t_buf[t_index] <= char_in;
            if (char_in == "0") zeros_t <= zeros_t + 1;
            else if (char_in == "1") ones_t <= ones_t + 1;
            t_index <= t_index + 1;
          end
        end
        COMPUTE_PREFIX: begin
          if (prefix_index == 0) begin
            pi[0] <= 0;
            prefix_index <= prefix_index + 1;
          end else if (prefix_index < t_length) begin
            temp_len <= pi[prefix_index - 1];
            while (temp_len > 0 && t_buf[prefix_index] != t_buf[temp_len]) begin
              temp_len <= pi[temp_len - 1];
            end
            if (t_buf[prefix_index] == t_buf[temp_len]) begin
              temp_len <= temp_len + 1;
            end
            pi[prefix_index] <= temp_len;
            prefix_index <= prefix_index + 1;
          end
        end
        FIND_OVERLAP: begin
          overlap_len <= pi[t_length - 1];
          repeat_zeros <= 0;
          repeat_ones <= 0;
          for (int i = overlap_len; i < t_length; i = i + 1) begin
            if (t_buf[i] == "0") repeat_zeros <= repeat_zeros + 1;
            else repeat_ones <= repeat_ones + 1;
          end
          if (repeat_zeros == 0 || repeat_ones == 0) begin
            repeat_count <= 0;
          end else begin
            repeat_count <= (zeros_s / repeat_zeros) < (ones_s / repeat_ones) ? (zeros_s / repeat_zeros) : (ones_s / repeat_ones);
          end
          remaining_zeros <= zeros_s - (repeat_count * repeat_zeros);
          remaining_ones <= ones_s - (repeat_count * repeat_ones);
          out_index <= 0;
        end
        ASSEMBLE_OUTPUT: begin
          if (out_index < t_length) begin
            char_out <= t_buf[out_index];
            valid_out <= 1;
          end else if (out_index < t_length + (repeat_count * (t_length - overlap_len))) begin
            char_out <= t_buf[overlap_len + ((out_index - t_length) % (t_length - overlap_len))];
            valid_out <= 1;
          end else if (out_index < t_length + (repeat_count * (t_length - overlap_len)) + remaining_zeros) begin
            char_out <= "0";
            valid_out <= 1;
          end else if (out_index < t_length + (repeat_count * (t_length - overlap_len)) + remaining_zeros + remaining_ones) begin
            char_out <= "1";
            valid_out <= 1;
          end else begin
            valid_out <= 0;
          end
          out_index <= out_index + 1;
        end
        DONE: begin
          done <= 1;
          valid_out <= 0;
        end
      endcase
    end
  end

endmodule