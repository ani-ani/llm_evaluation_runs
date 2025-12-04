module pirates_game_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  input [9:0] a[0:14],
  output reg [13:0] result,
  output reg done
);

  // FSM states
  localparam IDLE = 2'd0;
  localparam PROC = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state;
  reg [3:0] x_ptr;           // current chest index
  reg [13:0] acc_sum;        // accumulated moves sum
  reg [9:0] data_reg[0:14];  // working copy of chest values

  // Validity check flag
  reg valid_n;

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      result  <= 14'sd0;
      x_ptr   <= 4'd0;
      acc_sum <= 14'd0;
      valid_n <= 1'b0;
      for (i = 0; i < 15; i = i + 1) begin
        data_reg[i] <= 10'd0;
      end
    end else begin
      done <= 1'b0; // default
      case (state)
        IDLE: begin
          if (start) begin
            // Check validity of n_in
            if ((n_in <= 4'd1) || (n_in[0] == 1'b0)) begin
              // invalid: output -1 immediately (1 cycle latency already inherent)
              result  <= 14'h3FFF; // -1 in 14-bit two's complement
              done    <= 1'b1;
              state   <= DONE;
              valid_n <= 1'b0;
            end else begin
              // valid: capture inputs and prepare for processing
              for (i = 0; i < 15; i = i + 1) begin
                data_reg[i] <= a[i];
              end
              acc_sum <= 14'd0;
              x_ptr   <= n_in - 1'b1; // start from n_in-1
              valid_n <= 1'b1;
              state   <= PROC;
            end
          end
        end

        PROC: begin
          if (valid_n) begin
            if (x_ptr != 4'd0) begin
              // Compute children indices: 2*x_ptr and 2*x_ptr+1
              // Use guarded access; outside n_in range contributes 0
              reg [9:0] child0;
              reg [9:0] child1;
              reg [9:0] max_child;
              integer idx0;
              integer idx1;
              idx0 = (x_ptr << 1);
              idx1 = (x_ptr << 1) + 1;

              if (idx0 < n_in)
                child0 = data_reg[idx0];
              else
                child0 = 10'd0;

              if (idx1 < n_in)
                child1 = data_reg[idx1];
              else
                child1 = 10'd0;

              if (child0 >= child1)
                max_child = child0;
              else
                max_child = child1;

              // Update parent and accumulator
              data_reg[x_ptr] <= data_reg[x_ptr] - max_child;
              acc_sum         <= acc_sum + max_child;

              // Move to next chest index
              x_ptr <= x_ptr - 1'b1;
            end else begin
              // All required indices processed; produce final result next
              // Add root chest value to accumulated max sum
              result <= acc_sum + data_reg[0];
              done   <= 1'b1;
              state  <= DONE;
            end
          end else begin
            // Should not occur; fallback to IDLE
            state <= IDLE;
          end
        end

        DONE: begin
          // Hold result stable; done was pulsed high in prior cycle
          // Return to IDLE, waiting for next start
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule