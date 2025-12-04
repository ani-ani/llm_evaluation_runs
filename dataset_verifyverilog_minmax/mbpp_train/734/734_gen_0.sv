module sum_subarray_prod(
  input clk,
  input rst_n,
  input start,
  input [3:0] element [7:0],
  input [2:0] arr_len,
  output reg [31:0] result,
  output reg done
);

  typedef enum {IDLE, COMPUTE, DONE} state_t;
  state_t state;
  reg [31:0] ans;
  reg [31:0] res;
  reg [31:0] incr;
  reg [2:0] counter;
  reg [3:0] current_element;
  reg [31:0] temp_res;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ans <= 0;
      res <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            ans <= 0;
            res <= 0;
            counter <= 0;
          end
        end
        COMPUTE: begin
          if (counter < arr_len) begin
            current_element = element[arr_len - 1 - counter];
            temp_res = 1 + res;
            incr = current_element * temp_res;
            ans <= ans + incr;
            res <= incr;
            counter <= counter + 1;
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          state <= IDLE;
        end
      endcase
    end
  end

  always @(*) begin
    if (state == DONE) begin
      result = ans;
      done = 1'b1;
    end else begin
      result = 0;
      done = 1'b0;
    end
  end

endmodule