module int_base_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] x,
  input [3:0] base,
  output reg [31:0] digits,
  output reg valid
);

  // Internal signals
  logic [7:0] base_r;
  logic [3:0] rem_storage [0:7];
  logic [2:0] i;
  logic [2:0] j;
  logic [7:0] q;
  logic [7:0] r;
  logic div_done;
  logic rev_done;

  // Compute one division-by-base step (Newton-Raphson style long division)
  always_comb begin
    logic [7:0] div_q;
    logic [7:0] div_r;
    logic [7:0] cur;
    logic [3:0] b;
    logic [7:0] t;
    div_q = 8'h0;
    div_r = 8'h0;
    cur = 8'h0;
    b = base_r;
    // 8 cycles of shift-and-subtract for 8-bit dividend
    cur = {div_r[6:0], q[7]};
    t = b;
    if (t <= cur) begin
      div_r = cur - t;
      div_q[7] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[6]};
    t = {b[2:0], 1'b0}; // 2*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[6] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[5]};
    t = {b[1:0], 2'b0}; // 4*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[5] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[4]};
    t = {b[0], 3'b0, 1'b0}; // 8*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[4] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[3]};
    t = {4{b}}; // 16*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[3] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[2]};
    t = {3{b}, 1'b0}; // 32*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[2] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[1]};
    t = {2{b}, 2'b0}; // 64*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[1] = 1'b1;
    end else begin
      div_r = cur;
    end
    cur = {div_r[6:0], q[0]};
    t = {b, 3'b0}; // 128*b
    if (t <= cur) begin
      div_r = cur - t;
      div_q[0] = 1'b1;
    end else begin
      div_r = cur;
    end
  end
  assign q = div_q;
  assign r = div_r;
  assign div_done = (i == 3'd7);

  // Sequential state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      digits <= 32'h0;
      valid <= 1'b0;
      i <= 3'd0;
      j <= 3'd0;
      base_r <= 4'd0;
      rem_storage[0] <= 4'd0;
      rem_storage[1] <= 4'd0;
      rem_storage[2] <= 4'd0;
      rem_storage[3] <= 4'd0;
      rem_storage[4] <= 4'd0;
      rem_storage[5] <= 4'd0;
      rem_storage[6] <= 4'd0;
      rem_storage[7] <= 4'd0;
    end else begin
      valid <= 1'b0;
      if (start) begin
        // Sample inputs and initialize
        base_r <= base;
        i <= 3'd0;
        j <= 3'd0;
        rem_storage[0] <= 4'd0;
        rem_storage[1] <= 4'd0;
        rem_storage[2] <= 4'd0;
        rem_storage[3] <= 4'd0;
        rem_storage[4] <= 4'd0;
        rem_storage[5] <= 4'd0;
        rem_storage[6] <= 4'd0;
        rem_storage[7] <= 4'd0;
        // First division uses original x
        q <= x;
      end else if (!div_done) begin
        // 8 cycles of successive division to collect remainders
        rem_storage[i] <= r[3:0];
        q <= q;
        i <= i + 1;
        j <= j;
        // Next division uses the quotient from the previous step
        q <= q;
      end else if (!rev_done) begin
        // Reverse stored remainders into 4-bit digit field
        j <= j + 1;
        case (j)
          3'd0: digits[31:28] <= rem_storage[7];
          3'd1: digits[27:24] <= rem_storage[6];
          3'd2: digits[23:20] <= rem_storage[5];
          3'd3: digits[19:16] <= rem_storage[4];
          3'd4: digits[15:12] <= rem_storage[3];
          3'd5: digits[11:8]  <= rem_storage[2];
          3'd6: digits[7:4]   <= rem_storage[1];
          3'd7: digits[3:0]   <= rem_storage[0];
        endcase
        if (j == 3'd7) begin
          valid <= 1'b1;
          rev_done <= 1'b1;
        end
      end else begin
        // Idle until next start
        rev_done <= 1'b0;
      end
    end
  end

endmodule
