module divisible_checker (
  input reg clk, rst_n, start,
  input reg [7:0] start_num, end_num,
  output reg [7:0] results [0:15],
  output reg [4:0] count,
  output reg done
);

  // State machine parameters
  localparam IDLE = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam CHECK_DIGITS = 2'd2;
  localparam DONE = 2'd3;

  // State registers
  reg [1:0] state, next_state;
  reg [7:0] curr_num;
  
  // Internal signals for digit checking
  wire [7:0] d1 = curr_num % 10;
  wire [7:0] d2 = (curr_num / 10) % 10;
  wire [7:0] d3 = curr_num / 100;
  wire valid = (d1 == 0 || curr_num % d1 == 0) &&
               (d2 == 0 || curr_num % d2 == 0) &&
               (d3 == 0 || curr_num % d3 == 0);

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      curr_num <= 0;
      count <= 0;
      done <= 0;
      for (int i = 0; i < 16; i++) results[i] <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          if (start) begin
            curr_num <= start_num;
            count <= 0;
          end
        end
        PROCESSING: begin
          if (curr_num > end_num) begin
            next_state <= DONE;
          end else begin
            next_state <= CHECK_DIGITS;
          end
        end
        CHECK_DIGITS: begin
          if (valid && count < 16) begin
            results[count] <= curr_num;
            count <= count + 1;
          end
          curr_num <= curr_num + 1;
          next_state <= PROCESSING;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            next_state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: next_state = start ? PROCESSING : IDLE;
      PROCESSING: next_state = (curr_num > end_num) ? DONE : CHECK_DIGITS;
      CHECK_DIGITS: next_state = PROCESSING;
      DONE: next_state = (!start) ? IDLE : DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule