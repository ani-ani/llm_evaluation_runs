module prime_generator (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [4:0] prime,
  output reg valid,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    INIT_CHECK,
    CHECK,
    PRIME_FOUND,
    NEXT_CANDIDATE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [4:0] candidate;
  reg [4:0] divisor;
  wire [4:0] max_divisor;
  reg start_prev;
  wire start_pulse = start && !start_prev;

  always_comb begin
    case (candidate)
      5'd0:    max_divisor = 5'd0;
      5'd1:    max_divisor = 5'd0;
      5'd2:    max_divisor = 5'd1;
      5'd3:    max_divisor = 5'd1;
      5'd4:    max_divisor = 5'd2;
      5'd5,5'd6: max_divisor = 5'd2;
      5'd7,5'd8: max_divisor = 5'd2;
      5'd9:    max_divisor = 5'd3;
      5'd10,5'd11,5'd12,5'd13,5'd14,5'd15: max_divisor = 5'd3;
      5'd16,5'd17,5'd18,5'd19: max_divisor = 5'd4;
      default: max_divisor = 5'd0;
    endcase
  end

  wire [4:0] rem_div = candidate % divisor;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      start_prev <= 0;
      candidate <= 5'd0;
      divisor <= 5'd0;
      prime <= 5'd0;
      valid <= 0;
      done <= 0;
    end else begin
      start_prev <= start;
      valid <= 0;  
      case (state)
        IDLE: begin
          done <= 0;
          if (start_pulse) begin
            candidate <= 5'd2;
            state <= INIT_CHECK;
          end
        end

        INIT_CHECK: begin
          divisor <= 5'd2;
          if (5'd2 > max_divisor) begin
            state <= PRIME_FOUND;
          end else begin
            state <= CHECK;
          end
        end

        CHECK: begin
          if (divisor > max_divisor) begin
            state <= PRIME_FOUND;
          end else begin
            if (rem_div == 5'd0) begin
              state <= NEXT_CANDIDATE;
            end else begin
              divisor <= divisor + 1;
              state <= CHECK;
            end
          end
        end

        PRIME_FOUND: begin
          prime <= candidate;
          valid <= 1;
          state <= NEXT_CANDIDATE;
        end

        NEXT_CANDIDATE: begin
          candidate <= candidate + 1;
          if (candidate < n) begin
            state <= INIT_CHECK;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          if (start_pulse) begin
            candidate <= 5'd2;
            state <= INIT_CHECK;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule