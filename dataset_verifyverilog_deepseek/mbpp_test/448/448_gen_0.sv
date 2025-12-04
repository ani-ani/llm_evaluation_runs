module perrin_sum(input clk, rst_n, start, input [7:0] n, output reg [31:0] sum, output reg done);
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;
  reg [1:0] state, next_state;
  reg [7:0] counter, next_counter;
  reg [31:0] a, next_a;
  reg [31:0] b, next_b;
  reg [31:0] c, next_c;
  reg [31:0] next_sum;
  reg next_done;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 8'b0;
      a <= 32'b0;
      b <= 32'b0;
      c <= 32'b0;
      sum <= 32'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      counter <= next_counter;
      a <= next_a;
      b <= next_b;
      c <= next_c;
      sum <= next_sum;
      done <= next_done;
    end
  end

  always_comb begin
    next_state = state;
    next_counter = counter;
    next_a = a;
    next_b = b;
    next_c = c;
    next_sum = sum;
    next_done = 1'b0;
    
    case(state)
      IDLE: begin
        if (start) begin
          if (n <= 2) begin
            next_sum = (n == 2) ? 32'd5 : 32'd3;
            next_state = DONE;
          end else begin
            next_a = 32'd3;
            next_b = 32'd0;
            next_c = 32'd2;
            next_sum = 32'd5;
            next_counter = n - 3;
            next_state = COMPUTE;
          end
        end
      end

      COMPUTE: begin
        if (counter > 1) begin
          next_sum = sum + a + b;
          next_a = b;
          next_b = c;
          next_c = a + b;
          next_counter = counter - 1;
          next_state = COMPUTE;
        end else if (counter == 1) begin
          next_sum = sum + a + b;
          next_a = b;
          next_b = c;
          next_c = a + b;
          next_counter = 0;
          next_state = DONE;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        next_done = 1'b1;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end
endmodule