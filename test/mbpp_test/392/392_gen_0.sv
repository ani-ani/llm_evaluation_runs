module dynamic_max_sum (
  input  clk,
  input  rst_n,
  input  start,
  input  [4:0] n_in,
  output reg [15:0] result,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE    = 2'b10;

  reg [1:0] state, next_state;

  // Memory to store f[i]
  reg [15:0] f_mem [0:31];

  // Latched input
  reg [4:0] n_reg;

  // Loop index (current i)
  reg [4:0] i;

  // Wires/regs for computation
  reg [15:0] sum_val;
  reg [15:0] max_val;

  integer idx;

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (n_in <= 1) begin
            next_state = DONE;
          end else begin
            next_state = COMPUTE;
          end
        end
      end
      COMPUTE: begin
        if (i == n_reg) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // done is a one-cycle pulse; return to IDLE next cycle
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state   <= IDLE;
      n_reg   <= 5'd0;
      i       <= 5'd0;
      result  <= 16'd0;
      done    <= 1'b0;
      // Initialize memory: f[0] = 0, f[1] = 1, others 0
      f_mem[0] <= 16'd0;
      f_mem[1] <= 16'd1;
      for (idx = 2; idx < 32; idx = idx + 1) begin
        f_mem[idx] <= 16'd0;
      end
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, assert only in DONE state

      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n_in;
            if (n_in == 0) begin
              result <= f_mem[0];
            end else if (n_in == 1) begin
              result <= f_mem[1];
            end else begin
              // Start computing from i=2 up to n_reg
              i <= 5'd2;
            end
          end
        end

        COMPUTE: begin
          // Compute sum of sub-results
          sum_val = f_mem[i >> 1] + f_mem[i / 3] + f_mem[i >> 2] + f_mem[i / 5];

          // Select max(i, sum_val)
          if (sum_val > i)
            max_val = sum_val;
          else
            max_val = {11'd0, i};

          // Store f[i]
          f_mem[i] <= max_val;

          // Advance index; when i reaches n_reg, next_state will go to DONE
          if (i < n_reg)
            i <= i + 1'b1;
        end

        DONE: begin
          // Result is f[n_reg]
          result <= f_mem[n_reg];
          done   <= 1'b1; // one-cycle pulse
        end

        default: ;
      endcase
    end
  end

endmodule