module CirclesOfChairs #(
  parameter N = 8,
  parameter DATA_WIDTH = 32,
  parameter RESULT_WIDTH = 64
)(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [7:0] n,
  input wire [N*DATA_WIDTH-1:0] l_arr_packed,
  input wire [N*DATA_WIDTH-1:0] r_arr_packed,
  output reg [RESULT_WIDTH-1:0] result,
  output reg done
);

  // States
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] SORT = 2'd1;
  localparam [1:0] COMPUTE = 2'd2;
  localparam [1:0] DONE = 2'd3;

  reg [1:0] state, next_state;
  reg [DATA_WIDTH-1:0] l_mem [0:N-1];
  reg [DATA_WIDTH-1:0] r_mem [0:N-1];
  reg [7:0] n_reg;
  reg [RESULT_WIDTH-1:0] sum_reg;
  reg [7:0] i, j, k;
  reg sorting_done;
  reg [1:0] phase;

  // State transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE:     next_state = start ? SORT : IDLE;
      SORT:     next_state = sorting_done ? COMPUTE : SORT;
      COMPUTE:  next_state = (k >= n_reg) ? DONE : COMPUTE;
      DONE:     next_state = IDLE;
      default:  next_state = IDLE;
    endcase
  end

  // Output and internal registers
  always @(posedge clk or negedge rst_n) begin
    integer idx;
    if (!rst_n) begin
      done <= 0;
      result <= 0;
      n_reg <= 0;
      sum_reg <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      sorting_done <= 0;
      phase <= 0;
      for (idx = 0; idx < N; idx = idx + 1) begin
        l_mem[idx] <= 0;
        r_mem[idx] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          sorting_done <= 0;
          if (start) begin
            // Latch inputs
            n_reg <= n;
            for (idx = 0; idx < N; idx = idx + 1) begin
              l_mem[idx] <= l_arr_packed[idx*DATA_WIDTH +: DATA_WIDTH];
              r_mem[idx] <= r_arr_packed[idx*DATA_WIDTH +: DATA_WIDTH];
            end
            // Initialize sorting counters
            i <= 0;
            j <= 0;
            k <= 0;
            sum_reg <= 0;
            phase <= 0;
          end
        end

        SORT: begin
          // Bubble sort for l_mem and r_mem
          // Process one comparison per cycle
          if (!sorting_done) begin
            if (i < N-1) begin
              if (j < N-1 - i) begin
                // Compare and swap l_mem
                if (l_mem[j] > l_mem[j+1]) begin
                  l_mem[j]   <= l_mem[j+1];
                  l_mem[j+1] <= l_mem[j];
                end
                // Compare and swap r_mem
                if (r_mem[j] > r_mem[j+1]) begin
                  r_mem[j]   <= r_mem[j+1];
                  r_mem[j+1] <= r_mem[j];
                end
                j <= j + 1;
              end else begin
                i <= i + 1;
                j <= 0;
              end
            end else begin
              sorting_done <= 1;
            end
          end
        end

        COMPUTE: begin
          if (k < n_reg) begin
            // Add max(l_mem[k], r_mem[k]) to sum
            if (l_mem[k] > r_mem[k])
              sum_reg <= sum_reg + l_mem[k];
            else
              sum_reg <= sum_reg + r_mem[k];
            k <= k + 1;
          end else begin
            // Compute final result
            result <= n_reg + sum_reg;
            done <= 1;
          end
        end

        DONE: begin
          done <= 0;
          // Ensure clean return to IDLE
        end
        
        default: begin
          done <= 0;
          result <= 0;
        end
      endcase
    end
  end

endmodule