module bracket_correction(
  input clk,
  input rst_n,
  input start,
  input [3:0] seq_len,
  input [15:0] bracket_seq,
  output reg [4:0] result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    CHECK_VALID,
    PROCESS,
    DONE
  } state_t;

  state_t state, next_state;
  reg signed [5:0] balance;
  reg in_neg;
  reg [4:0] current_seg_len;
  reg [4:0] total_time;
  reg [3:0] pos;
  reg [15:0] seq_shift;

  wire is_even = (seq_len[0] == 1'b0);
  wire [4:0] expected_ones = {1'b0, seq_len[3:1]};
  wire [15:0] mask = ~(16'hFFFF << seq_len);
  wire [15:0] masked_seq = bracket_seq & mask;
  wire [4:0] actual_ones;
  wire valid = is_even && (actual_ones == expected_ones);

  always_comb begin
    automatic int count = 0;
    for (int i=0; i<16; i++) begin
      if (masked_seq[i]) count++;
    end
    actual_ones = count[4:0];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      balance <= 0;
      in_neg <= 0;
      current_seg_len <= 0;
      total_time <= 0;
      pos <= 0;
      seq_shift <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 0;
          if (start) next_state <= CHECK_VALID;
          else next_state <= IDLE;
        end

        CHECK_VALID: begin
          if (valid) begin
            next_state <= PROCESS;
            seq_shift <= bracket_seq;
            pos <= 0;
            balance <= 0;
            in_neg <= 0;
            current_seg_len <= 0;
            total_time <= 0;
          end else begin
            result <= 5'b11111;
            done <= 1;
            next_state <= IDLE;
          end
        end

        PROCESS: begin
          if (pos < seq_len) begin
            if (seq_shift[15]) balance <= balance + 1;
            else balance <= balance - 1;
            seq_shift <= seq_shift << 1;
            pos <= pos + 1;

            if (balance + (seq_shift[15] ? 1 : -1) < 0) begin
              if (!in_neg) begin
                in_neg <= 1;
                current_seg_len <= 1;
              end else begin
                current_seg_len <= current_seg_len + 1;
              end
            end else begin
              if (in_neg) begin
                total_time <= total_time + current_seg_len;
                in_neg <= 0;
                current_seg_len <= 0;
              end
            end
          end else begin
            next_state <= DONE;
          end
        end

        DONE: begin
          if (in_neg) result <= total_time + current_seg_len;
          else result <= total_time;
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end
endmodule