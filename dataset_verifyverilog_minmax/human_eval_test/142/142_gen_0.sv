module sum_squares (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] length,
  input reg signed [15:0] lst_0,
  input reg signed [15:0] lst_1,
  input reg signed [15:0] lst_2,
  input reg signed [15:0] lst_3,
  input reg signed [15:0] lst_4,
  input reg signed [15:0] lst_5,
  input reg signed [15:0] lst_6,
  input reg signed [15:0] lst_7,
  output reg signed [31:0] sum,
  output reg done
);
  // State encoding
  parameter IDLE = 2'b00;
  parameter ACTIVE = 2'b01;
  parameter DONE = 2'b10;

  // Internal registers
  reg [1:0] state, next_state;
  reg [3:0] index, next_index;
  reg signed [31:0] next_sum;
  reg next_done;
  logic signed [15:0] cur;
  logic signed [63:0] add;

  // Combinational logic to compute next state and outputs
  always_comb begin
    // default assignments
    next_state = state;
    next_index = index;
    next_sum = sum;
    next_done = done;

    if (state == IDLE || state == DONE) begin
      if (start) begin
        next_state = ACTIVE;
        next_index = 4'h0;
        next_sum = 32'h0;
        next_done = 1'b0;
      end
    end else if (state == ACTIVE) begin
      if (length == 4'h0) begin
        // No elements to process - skip directly to DONE
        next_state = DONE;
        next_done = 1'b1;
        // sum remains as is (already zero)
        next_index = index; // remains 0
      end else begin
        // Select current element based on index
        case (index)
          4'd0: cur = lst_0;
          4'd1: cur = lst_1;
          4'd2: cur = lst_2;
          4'd3: cur = lst_3;
          4'd4: cur = lst_4;
          4'd5: cur = lst_5;
          4'd6: cur = lst_6;
          4'd7: cur = lst_7;
          default: cur = 16'h0;
        endcase

        // Compute the term to add based on index
        if (index == 4'd0 || index == 4'd3 || index == 4'd6) begin
          // Square the value
          add = $signed(cur) * $signed(cur);
        end else if (index == 4'd4) begin
          // Cube the value
          add = $signed(cur) * $signed(cur) * $signed(cur);
        end else begin
          // Use the value itself
          add = $signed(cur);
        end

        // Update sum (truncation to 32-bit occurs automatically)
        next_sum = sum + add;

        // Increment index for next cycle
        next_index = index + 1;

        // Determine if all elements have been processed
        if (next_index == length) begin
          next_state = DONE;
          next_done = 1'b1;
        end else begin
          next_state = ACTIVE;
          next_done = 1'b0;
        end
      end
    end
  end

  // Sequential block: update state and outputs on clock edge
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 4'h0;
      sum <= 32'h0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      index <= next_index;
      sum <= next_sum;
      done <= next_done;
    end
  end
endmodule
