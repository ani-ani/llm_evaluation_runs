module simple_power (
  input clk,
  input rst_n,
  input start,
  input [7:0] x,
  input [7:0] n,
  output reg result,
  output reg done
);

  // State encoding
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  // State register
  reg [1:0] state, next_state;

  // Internal registers
  reg [31:0] current_power;
  reg [4:0] k;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_power <= 32'b0;
      k <= 5'b0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          current_power = 32'b1;  // Initialize to n^0 = 1
          k = 5'b0;
          result = 1'b0;
          done = 1'b0;
        end
      end
      PROCESSING: begin
        if (current_power[7:0] == x) begin
          result = 1'b1;
          next_state = DONE;
        end else if (current_power[7:0] > x || k == 5'd31) begin
          result = 1'b0;
          next_state = DONE;
        end else begin
          current_power = current_power * n;
          k = k + 1;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          result = 1'b0;
          done = 1'b0;
        end
      end
    endcase
  end

  // Special cases handling
  always @(*) begin
    if (state == PROCESSING) begin
      // Special case: n == 0
      if (n == 8'b0) begin
        if (x == 8'b1) begin
          result = 1'b1;
          next_state = DONE;
        end else begin
          result = 1'b0;
          next_state = DONE;
        end
      end
      // Special case: n == 1
      else if (n == 8'b1) begin
        if (x == 8'b1) begin
          result = 1'b1;
          next_state = DONE;
        end else begin
          result = 1'b0;
          next_state = DONE;
        end
      end
      // Special case: x == 1 (already handled by current_power == x)
    end
  end

  // Done signal
  always @(*) begin
    done = (state == DONE);
  end

endmodule