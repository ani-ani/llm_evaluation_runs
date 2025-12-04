module nsw_prime (
  input        clk,
  input        rst_n,
  input        start,
  input  [4:0] n_in,
  output reg [15:0] result,
  output reg        done
);

  // Internal registers
  reg [15:0] curr;
  reg [15:0] prev;
  reg [4:0]  n_reg;       // Latched n
  reg [4:0]  step_cnt;    // Iteration counter
  reg        busy;        // Indicates active computation

  // Asynchronous reset, synchronous operation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result   <= 16'd0;
      done     <= 1'b0;
      curr     <= 16'd0;
      prev     <= 16'd0;
      n_reg    <= 5'd0;
      step_cnt <= 5'd0;
      busy     <= 1'b0;
    end else begin
      // Default: done deasserted unless set below
      done <= 1'b0;

      if (start && !busy) begin
        // Latch input n and initialize
        n_reg    <= n_in;
        step_cnt <= 5'd0;

        if (n_in == 5'd0 || n_in == 5'd1) begin
          // For n = 0 or 1, result = 1 after 1 cycle
          result <= 16'd1;
          done   <= 1'b1;
          busy   <= 1'b0;
          curr   <= 16'd1;
          prev   <= 16'd0;
        end else begin
          // Initialize for iterative computation
          // Using U_0 = 1, U_1 = 1 for NSW-like recurrence
          prev   <= 16'd1;   // U_0
          curr   <= 16'd1;   // U_1
          busy   <= 1'b1;
        end

      end else if (busy) begin
        // Iterative computation: next = 2*curr + prev
        // All arithmetic is 16-bit unsigned (wrap on overflow)
        // Perform one iteration per cycle
        prev <= curr;
        curr <= (curr << 1) + prev;
        step_cnt <= step_cnt + 5'd1;

        // Need (n_reg - 1) iterations total; step_cnt counts completed steps
        if (step_cnt == (n_reg - 2)) begin
          // This cycle produced the final value in 'curr' next cycle's assignment
          // But since we use non-blocking, 'curr' already holds U_1 initially;
          // after (n_reg-1) updates, 'curr' is U_n.
          // When condition true, the just-updated 'curr' is U_n.
          result <= (curr << 1) + prev; // mirror the computed value for clarity
          done   <= 1'b1;
          busy   <= 1'b0;
        end
      end
    end
  end

endmodule