module prime_factorization(
  input clk,
  input rst_n,
  input start,
  input [15:0] n_in,
  output reg [7:0] factors [0:15],
  output reg [3:0] factor_count,
  output reg valid
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE     = 2'b00,
    DIVIDE   = 2'b01,
    INCREMENT= 2'b10,
    DONE     = 2'b11
  } state_t;

  state_t state, next_state;

  reg [15:0] remainder;
  reg [15:0] divisor;
  reg        start_d;
  wire       start_pulse;

  // Start pulse detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  // Sequential state and data registers
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      remainder    <= 16'd0;
      divisor      <= 16'd2;
      factor_count <= 4'd0;
      valid        <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        factors[i] <= 8'd0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          valid <= 1'b0;
          if (start_pulse) begin
            remainder    <= n_in;
            divisor      <= 16'd2;
            factor_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
              factors[i] <= 8'd0;
            end
          end
        end

        DIVIDE: begin
          valid <= 1'b0;
          if (remainder % divisor == 16'd0) begin
            // Store factor
            if (factor_count < 4'd16) begin
              factors[factor_count] <= divisor[7:0];
              factor_count          <= factor_count + 4'd1;
            end
            remainder <= remainder / divisor;
          end
        end

        INCREMENT: begin
          valid   <= 1'b0;
          divisor <= divisor + 16'd1;
        end

        DONE: begin
          // Assert valid for one cycle
          valid <= 1'b1;
        end

        default: begin
          valid <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = DIVIDE;
        else
          next_state = IDLE;
      end

      DIVIDE: begin
        if (remainder == 16'd1) begin
          next_state = DONE;
        end else if (remainder % divisor == 16'd0) begin
          // Stay in DIVIDE to keep factoring by same divisor
          next_state = DIVIDE;
        end else begin
          next_state = INCREMENT;
        end
      end

      INCREMENT: begin
        if (remainder == 16'd1)
          next_state = DONE;
        else
          next_state = DIVIDE;
      end

      DONE: begin
        // Return to IDLE after one valid cycle
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule