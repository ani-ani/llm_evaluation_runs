module apple_tree #(
  parameter N = 16,      // Maximum number of nodes
  parameter DATA_WIDTH = 4 // Bit width for node indices (1-16)
) (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire load,           // Load signal for parent input
  input wire [DATA_WIDTH-1:0] parent,   // Parent of current node (1-based)
  output reg [DATA_WIDTH-1:0] result,
  output reg done
);

  // Internal signals and registers
  reg [DATA_WIDTH-1:0] depth_mem [0:N-1];   // Depth storage for each node
  reg parity_mem [0:15];         // Parity storage for depths 0-15
  reg [DATA_WIDTH-1:0] total;    // Total apples collected
  reg [DATA_WIDTH-1:0] idx;      // Current node index (0 to N-1)
  reg [2:0] state;               // State machine

  // States
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam LOAD = 3'b010;
  localparam DONE = 3'b011;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      total <= 0;
      idx <= 0;
      // Reset parity memory
      for (i = 0; i < 16; i = i + 1) begin
        parity_mem[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize node 1 (root)
            depth_mem[0] <= 0;
            // Update parity for depth 0
            parity_mem[0] <= ~parity_mem[0];
            if (parity_mem[0] == 0)
              total <= total + 1;
            else
              total <= total - 1;
            idx <= 1;  // Next node will be node 2 (index 1)
            state <= INIT;
            done <= 0;
          end
        end

        INIT: begin
          state <= LOAD;
        end

        LOAD: begin
          if (load && idx < N) begin
            // Compute depth: depth = depth_mem[parent-1] + 1
            // Update depth memory for current node
            depth_mem[idx] <= depth_mem[parent-1] + 1;
            // Update parity and total for the new depth
            if (parity_mem[depth_mem[parent-1] + 1] == 0) begin
              total <= total + 1;
            end else begin
              total <= total - 1;
            end
            parity_mem[depth_mem[parent-1] + 1] <= ~parity_mem[depth_mem[parent-1] + 1];
            idx <= idx + 1;
            if (idx == N-1) begin
              state <= DONE;
              done <= 1;
              result <= total;
            end
          end else if (idx >= N) begin
            state <= DONE;
            done <= 1;
            result <= total;
          end
        end

        DONE: begin
          // Hold result until reset
          done <= 1;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule