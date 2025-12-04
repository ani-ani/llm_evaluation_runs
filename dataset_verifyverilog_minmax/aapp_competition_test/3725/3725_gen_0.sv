module frog_flower_sync(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [15:0] m, // Modulo value (2 ≤ m ≤ 65535)
  input [15:0] h1, a1, x1, y1, // Frog parameters (h1 ≠ a1)
  input [15:0] h2, a2, x2, y2, // Flower parameters (h2 ≠ a2)
  output reg [11:0] time_out, // Minimum sync time (0-3071)
  output reg done, // High when finished
  output reg fail // High if no solution found
);

  // State machine encoding
  localparam IDLE     = 1'b0;
  localparam RUNNING  = 1'b1;

  // Internal state
  reg state, next_state;
  reg [15:0] cur_h1, cur_h2;     // current LCG values
  reg [11:0] count;              // elapsed cycles (0..3071)

  // Compute next LCG values: h_next = (x * h + y) % m
  wire [31:0] h1_mul = x1 * cur_h1 + y1;
  wire [31:0] h2_mul = x2 * cur_h2 + y2;
  wire [15:0] h1_next = h1_mul % m;
  wire [15:0] h2_next = h2_mul % m;

  // Match detection at current cycle
  wire match = (cur_h1 == a1) && (cur_h2 == a2);
  wire timeout = (count == 12'hFFF); // after 3072 cycles with no match

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE:    next_state = (start && rst_n) ? RUNNING : IDLE;
      RUNNING: next_state = (match || timeout) ? IDLE : RUNNING;
      default: next_state = IDLE;
    endcase
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Counter and LCG registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count  <= 12'h0;
      cur_h1 <= 16'h0;
      cur_h2 <= 16'h0;
    end else begin
      case (state)
        IDLE: begin
          count  <= 12'h0;
          cur_h1 <= 16'h0;
          cur_h2 <= 16'h0;
        end
        RUNNING: begin
          if (match) begin
            // Hold steady once result is found
            count  <= count;
            cur_h1 <= cur_h1;
            cur_h2 <= cur_h2;
          end else if (timeout) begin
            // Lock outputs for final cycle of run
            count  <= count;
            cur_h1 <= cur_h1;
            cur_h2 <= cur_h2;
          end else begin
            count  <= count + 1;
            cur_h1 <= h1_next;
            cur_h2 <= h2_next;
          end
        end
      endcase
    end
  end

  // Outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      time_out <= 12'h0;
      done     <= 1'b0;
      fail     <= 1'b0;
    end else begin
      done <= 1'b0;
      fail <= 1'b0;

      case (state)
        IDLE: begin
          time_out <= 12'h0;
        end
        RUNNING: begin
          if (match) begin
            time_out <= count;  // current cycle count (0..3071)
            done     <= 1'b1;
          end else if (timeout) begin
            time_out <= 12'h0;
            fail     <= 1'b1;
            done     <= 1'b1;
          end
        end
      endcase
    end
  end

endmodule