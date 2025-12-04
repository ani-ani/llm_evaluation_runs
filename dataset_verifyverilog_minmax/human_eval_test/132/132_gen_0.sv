module bracket_nested_check (
  input clk,
  input rst_n,
  input start,
  input [3:0] length,
  input [15:0] data,
  output reg result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam ACTIVE = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [3:0] count;         // 1..length while active
  reg [3:0] depth;         // current depth (0..15)
  reg nested_flag;         // 1 if nested ']' encountered at depth>=2
  reg [3:0] idx;           // bit index (LSB first)

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 4'd0;
      depth <= 4'd0;
      nested_flag <= 1'b0;
      idx <= 4'd0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= (next_state == DONE);   // 1-cycle pulse
      case (next_state)
        IDLE: begin
          count <= 4'd0;
          depth <= 4'd0;
          nested_flag <= 1'b0;
          idx <= 4'd0;
          result <= 1'b0;
        end
        ACTIVE: begin
          // Update counters and state in-order
          idx <= idx + 1'b1;
          count <= count + 1'b1;
          // Process current LSB
          if (data[idx]) begin
            // Closing bracket ']'
            if (depth >= 4'd2) nested_flag <= 1'b1;
            depth <= (depth == 4'd0) ? 4'd0 : (depth - 1'b1);
          end else begin
            // Opening bracket '['
            depth <= (depth == 4'd15) ? 4'd15 : (depth + 1'b1);
          end
        end
        DONE: begin
          result <= nested_flag;
          count <= 4'd0;
          idx <= 4'd0;
          depth <= 4'd0;
          nested_flag <= 1'b0;
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: next_state = start ? ACTIVE : IDLE;
      ACTIVE: next_state = (count == length) ? DONE : ACTIVE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule
