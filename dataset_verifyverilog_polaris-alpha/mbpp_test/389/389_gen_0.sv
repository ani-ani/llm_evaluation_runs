module lucas_number(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [10:0] result,
  output reg done
);

  reg [3:0] count;      // Iteration counter
  reg [10:0] prev2;     // L(k-2)
  reg [10:0] prev1;     // L(k-1)
  reg state;            // 0 = IDLE/READY, 1 = COMPUTING

  localparam IDLE = 1'b0;
  localparam COMPUTE = 1'b1;

  wire start_pulse;
  reg start_d;

  // Detect rising edge of start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      result <= 11'd0;
      done   <= 1'b0;
      count  <= 4'd0;
      prev2  <= 11'd0;
      prev1  <= 11'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            if (n == 4'd0) begin
              result <= 11'd2;
              done   <= 1'b1;
            end else if (n == 4'd1) begin
              result <= 11'd1;
              done   <= 1'b1;
            end else begin
              // Initialize for iterative computation
              prev2 <= 11'd2;      // L(0)
              prev1 <= 11'd1;      // L(1)
              count <= 4'd1;       // Next index to compute is 2
              done  <= 1'b0;
              state <= COMPUTE;
            end
          end
        end

        COMPUTE: begin
          // Compute next Lucas number
          // temp = prev1 + prev2;
          // Shift window: prev2 = prev1; prev1 = temp;
          // Increment count to represent newly computed index
          // When count == n after increment, computation is complete

          // Perform addition and update sequence
          // Using blocking assignments within sequential always is safe here
          // as this is a single always block FSM-style implementation.
          reg [10:0] next;
          next  = prev1 + prev2;
          prev2 <= prev1;
          prev1 <= next;
          count <= count + 4'd1;

          if (count + 4'd1 == n) begin
            result <= next;
            done   <= 1'b1;
            state  <= IDLE; // Return to IDLE/READY, output stays stable
          end else begin
            done <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule