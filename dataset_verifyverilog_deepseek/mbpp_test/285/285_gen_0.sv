module ab_pattern_check (
  input clk,
  input rst_n,
  input start,
  input [63:0] str_in,
  output reg match_found,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    CHECKING,
    FOUND_A,
    COUNT_B,
    DONE} state_t;

  state_t state, next_state;
  reg [2:0] b_count, next_b_count;
  reg [2:0] r_cnt, next_r_cnt;
  logic [7:0] current_byte;

  always_comb begin
    next_state = state;
    next_match_found = match_found;
    next_done = done;
    next_b_count = b_count;
    next_r_cnt = r_cnt;
    current_byte = str_in[(56 - (r_cnt*8)) +:8];

    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECKING;
          next_r_cnt = 3'b000;
          next_match_found = 1'b0;
          next_done = 1'b0;
          next_b_count = 3'b000;
        end
      end

      CHECKING: begin
        if (r_cnt == 3'b111) begin
          next_state = DONE;
        end else begin
          if (current_byte == 8'h61) begin
            next_state = FOUND_A;
          end
          next_r_cnt = r_cnt + 1'b1;
        end
      end

      FOUND_A: begin
        if (r_cnt == 3'b111) begin
          next_state = DONE;
        end else begin
          if (current_byte == 8'h62) begin
            next_state = COUNT_B;
            next_b_count = 3'b001;
          end else begin
            next_state = CHECKING;
          end
          next_r_cnt = r_cnt + 1'b1;
        end
      end

      COUNT_B: begin
        if (r_cnt == 3'b111) begin
          if ((b_count >= 3'b010) && (b_count <= 3'b011)) begin
            next_match_found = 1'b1;
          end
          next_state = DONE;
        end else begin
          if (current_byte == 8'h62) begin
            if (b_count < 3'b011) begin
              next_b_count = b_count + 1'b1;
              next_state = COUNT_B;
            end else begin
              next_state = CHECKING;
            end
          end else begin
            if ((b_count >= 3'b010) && (b_count <= 3'b011)) begin
              next_match_found = 1'b1;
            end
            next_state = CHECKING;
          end
          next_r_cnt = r_cnt + 1'b1;
        end
      end

      DONE: begin
        next_state = IDLE;
        next_done = 1'b1;
      end

      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      match_found <= 1'b0;
      done <= 1'b0;
      b_count <= 3'b000;
      r_cnt <= 3'b000;
    end else begin
      state <= next_state;
      match_found <= next_match_found;
      done <= next_done;
      b_count <= next_b_count;
      r_cnt <= next_r_cnt;
    end
  end

endmodule