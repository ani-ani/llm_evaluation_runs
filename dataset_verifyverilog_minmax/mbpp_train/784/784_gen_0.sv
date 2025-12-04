module first_even_odd_product (
  input clk,
  input rst_n,
  input start,
  input [7:0] list [0:7],
  output reg [15:0] product,
  output reg done,
  output reg found_pair
);

  // Internal signals
  reg [3:0] state, next_state;
  integer idx;
  reg [7:0] first_even, first_odd;
  reg even_found, odd_found;
  reg [7:0] captured_even, captured_odd;
  reg captured_pair;

  // State encoding: 0=IDLE, 1..8 = search cycles, 9 = result
  localparam IDLE   = 4'd0;
  localparam RESULT = 4'd9;

  // State transition (combinational)
  always @(*) begin
    case (state)
      IDLE:   next_state = start ? 4'd1 : IDLE;
      4'd1:   next_state = 4'd2;
      4'd2:   next_state = 4'd3;
      4'd3:   next_state = 4'd4;
      4'd4:   next_state = 4'd5;
      4'd5:   next_state = 4'd6;
      4'd6:   next_state = 4'd7;
      4'd7:   next_state = 4'd8;
      4'd8:   next_state = RESULT;
      RESULT: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      product      <= 16'h0;
      done         <= 1'b0;
      found_pair   <= 1'b0;
      first_even   <= 8'h0;
      first_odd    <= 8'h0;
      even_found   <= 1'b0;
      odd_found    <= 1'b0;
      captured_even <= 8'h0;
      captured_odd  <= 8'h0;
      captured_pair <= 1'b0;
    end else begin
      state <= next_state;

      // Defaults (avoid latches)
      product    <= product;
      done       <= 1'b0;
      found_pair <= found_pair;

      case (state)
        IDLE: begin
          product    <= 16'h0;
          done       <= 1'b0;
          found_pair <= 1'b0;
          if (start) begin
            idx           <= 0;
            first_even    <= 8'h0;
            first_odd     <= 8'h0;
            even_found    <= 1'b0;
            odd_found     <= 1'b0;
            captured_even <= 8'h0;
            captured_odd  <= 8'h0;
            captured_pair <= 1'b0;
          end
        end

        4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
          // Check current element
          if (!even_found && list[idx][0] === 1'b0) begin
            first_even <= list[idx];
            even_found <= 1'b1;
          end
          if (!odd_found && list[idx][0] === 1'b1) begin
            first_odd <= list[idx];
            odd_found <= 1'b1;
          end
          // Prepare for next cycle
          idx <= idx + 1;
        end

        RESULT: begin
          // Capture the first found pair for multiplication
          captured_even <= first_even;
          captured_odd  <= first_odd;
          captured_pair <= (even_found && odd_found);

          if (captured_pair) begin
            product    <= first_even * first_odd;
            found_pair <= 1'b1;
          end else begin
            product    <= 16'hFFFF; // Indicate not found
            found_pair <= 1'b0;
          end
          done <= 1'b1; // High for exactly one cycle
        end
      endcase
    end
  end
endmodule
