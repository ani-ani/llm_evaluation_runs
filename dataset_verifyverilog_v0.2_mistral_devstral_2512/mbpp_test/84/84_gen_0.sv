module newman_conway (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [4:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] CHECK_BASE = 3'b001;
  localparam [2:0] COMPUTE = 3'b010;
  localparam [2:0] DONE = 3'b011;

  // Register declarations
  reg [4:0] p_table [0:15]; // lookup table for P(1) through P(16)
  reg [4:0] current_n; // tracks which value we're computing
  reg [2:0] state; // state machine state
  reg [4:0] index; // current index being computed

  // Reset all registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_n <= 5'b0;
      result <= 5'b0;
      done <= 1'b0;
      index <= 5'b0;
      for (int i = 0; i < 16; i = i + 1) begin
        p_table[i] <= 5'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            current_n <= n;
            state <= CHECK_BASE;
          end
        end
        CHECK_BASE: begin
          if (current_n <= 2) begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end else begin
            p_table[1] <= 1;
            p_table[2] <= 1;
            index <= 3;
            state <= COMPUTE;
          end
        end
        COMPUTE: begin
          if (index > current_n) begin
            result <= p_table[current_n];
            done <= 1;
            state <= DONE;
          end else begin
            p_table[index] <= p_table[p_table[index-1]] + p_table[index - p_table[index-1]];
            index <= index + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule