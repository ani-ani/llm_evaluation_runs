module prime_checker (
  input              clk,
  input              rst_n,
  input              start,
  input        [7:0] num,
  output reg is_prime,
  output reg done
);

  typedef enum logic [1:0] {IDLE, CHECKING, DONE_ST} state_t;
  state_t state, next_state;

  reg [7:0] num_reg;           // Registered input number
  reg [4:0] divisor;           // Divisor counter (2 to 16)
  wire [8:0] div_squared = divisor * divisor;  // divisor^2 (max 16*16=256)

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      is_prime  <= 1'b0;
      done      <= 1'b0;
      num_reg   <= 8'd0;
      divisor   <= 5'd2;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            num_reg <= num;
            // Handle trivial cases immediately
            if (num < 8'd2) begin
              is_prime <= 1'b0;
              done     <= 1'b1;
              next_state <= DONE_ST;
            end else begin
              divisor   <= 5'd2;
              next_state <= CHECKING;
            end
          end
        end

        CHECKING: begin
          if (div_squared > num_reg) begin // No divisors found
            is_prime  <= 1'b1;
            done      <= 1'b1;
            next_state <= DONE_ST;
          end else if (num_reg % divisor == 0) begin // Divisor found
            is_prime  <= 1'b0;
            done      <= 1'b1;
            next_state <= DONE_ST;
          end else begin
            divisor <= divisor + 1;
          end
        end

        DONE_ST: begin
          done <= 1'b0;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end
endmodule