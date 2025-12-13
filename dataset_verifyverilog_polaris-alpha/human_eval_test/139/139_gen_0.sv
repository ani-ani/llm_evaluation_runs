module special_factorial (
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  output reg [63:0] result,
  output reg        done
);

  // State encoding
  localparam IDLE         = 2'b00;
  localparam COMPUTE_FACT = 2'b01;
  localparam MULTIPLY_PROD= 2'b10;
  localparam DONE         = 2'b11;

  reg [1:0]  state, next_state;

  reg [2:0]  k;            // Down counter for current factorial index
  reg [3:0]  m;            // Counter for factorial inner loop (up to 7)

  reg [63:0] product;      // Running Brazilian factorial product
  reg [63:0] fact_acc;     // Accumulator for current k! computation

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      result  <= 64'd1;
      done    <= 1'b0;
      product <= 64'd1;
      k       <= 3'd0;
      m       <= 4'd0;
      fact_acc<= 64'd1;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Hold previous outputs unless new start
          if (start) begin
            product <= 64'd1;      // initialize running product
            k       <= n;          // start from n
            fact_acc<= 64'd1;      // will be set when entering COMPUTE_FACT
            m       <= 4'd1;       // start factorial from 1
            done    <= 1'b0;
          end
        end

        COMPUTE_FACT: begin
          // Iteratively compute k! using m
          if (m == 4'd1) begin
            // Initialize factorial accumulator at first cycle for this k
            fact_acc <= 64'd1;
            m        <= 4'd2;
          end else if (m <= k) begin
            // Multiply by current m
            fact_acc <= fact_acc * m;
            m        <= m + 4'd1;
          end
          // When m > k, transition handled in next_state logic
        end

        MULTIPLY_PROD: begin
          // Multiply computed k! into running product
          product <= product * fact_acc;
          if (k > 3'd1) begin
            // Prepare for next k
            k       <= k - 3'd1;
            m       <= 4'd1;      // will re-init fact_acc in COMPUTE_FACT
          end
        end

        DONE: begin
          // Latch final result, assert done; hold values
          result <= product;
          done   <= 1'b1;
          // Wait in DONE until start deasserts, then go IDLE by next_state
        end

        default: begin
          // Safe default (should not occur)
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (n == 3'd0) begin
            // For n=0, define product as 1 and finish immediately
            next_state = DONE;
          end else begin
            next_state = COMPUTE_FACT;
          end
        end
      end

      COMPUTE_FACT: begin
        // When m just exceeded k, factorial is complete
        if (m > k) begin
          next_state = MULTIPLY_PROD;
        end else begin
          next_state = COMPUTE_FACT;
        end
      end

      MULTIPLY_PROD: begin
        if (k > 3'd1) begin
          // More factorials to compute
          next_state = COMPUTE_FACT;
        end else begin
          // All done (k==1 just multiplied)
          next_state = DONE;
        end
      end

      DONE: begin
        // Stay done until start is released, then go IDLE
        if (!start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule