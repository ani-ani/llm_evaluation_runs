module worm_cans (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  input [63:0] x [0:63],
  input [63:0] r [0:63],
  output reg [63:0] result [0:63],
  output reg done
);

  // Internal registers
  reg [5:0] i; // Current starting can index
  reg [5:0] j; // Loop index for propagation
  reg [63:0] current_mask; // Current explosion mask
  reg [63:0] next_mask; // Next explosion mask
  reg [63:0] visited; // Total visited mask
  reg [63:0] x_reg [0:63]; // Latched x values
  reg [63:0] r_reg [0:63]; // Latched r values
  reg [5:0] n_reg; // Latched n value
  reg [5:0] state; // State machine

  // State definitions
  localparam IDLE = 0;
  localparam SETUP_START = 1;
  localparam PROPAGATE = 2;
  localparam COUNT = 3;
  localparam NEXT_CAN = 4;
  localparam FINISHED = 5;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
      current_mask <= 0;
      next_mask <= 0;
      visited <= 0;
      done <= 0;
      state <= IDLE;
      for (int k = 0; k < 64; k = k + 1) begin
        result[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP_START;
          end
        end
        SETUP_START: begin
          // Latch inputs
          n_reg <= n;
          for (int k = 0; k < 64; k = k + 1) begin
            x_reg[k] <= x[k];
            r_reg[k] <= r[k];
          end
          i <= 0;
          visited <= 0;
          current_mask <= 0;
          next_mask <= 0;
          state <= PROPAGATE;
        end
        PROPAGATE: begin
          // Initialize current_mask with starting can
          if (j == 0) begin
            current_mask <= 1 << i;
            visited <= 1 << i;
          end
          // Calculate next_mask
          next_mask <= 0;
          for (int k = 0; k < 64; k = k + 1) begin
            if (current_mask[k]) begin
              for (int m = 0; m < 64; m = m + 1) begin
                if (!visited[m] && (m < n_reg)) begin
                  reg [63:0] distance;
                  distance = (x_reg[k] > x_reg[m]) ? (x_reg[k] - x_reg[m]) : (x_reg[m] - x_reg[k]);
                  if (distance <= r_reg[k]) begin
                    next_mask[m] <= 1'b1;
                  end
                end
              end
            end
          end
          // Update visited and current_mask
          visited <= visited | next_mask;
          current_mask <= next_mask;
          // Check if propagation is done
          if (next_mask == 0) begin
            state <= COUNT;
          end
        end
        COUNT: begin
          // Popcount visited and store in result[i]
          result[i] <= $countones(visited);
          state <= NEXT_CAN;
        end
        NEXT_CAN: begin
          i <= i + 1;
          if (i < n_reg) begin
            state <= SETUP_START;
          end else begin
            state <= FINISHED;
          end
        end
        FINISHED: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule