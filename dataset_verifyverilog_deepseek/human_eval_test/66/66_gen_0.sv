module uppercase_sum (
  input clk,
  input rst_n,
  input start,
  input [127:0] s_string,
  output reg [10:0] sum,
  output reg done
);

  localparam [3:0] MAX_COUNT = 4'd15;
  typedef enum {IDLE, PROCESS} state_t;
  reg [3:0] count;
  reg [10:0] sum_int;
  state_t state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_int <= 11'b0;
      done <= 1'b0;
      count <= 4'b0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            sum_int <= 11'b0;
            count <= 4'b0;
            state <= PROCESS;
          end
        end

        PROCESS: begin
          if (s_string[count*8 +: 8] >= 65 && s_string[count*8 +: 8] <= 90) begin
            sum_int <= sum_int + s_string[count*8 +: 8];
          end

          if (count == MAX_COUNT) begin
            done <= 1'b1;
            state <= IDLE;
          end else begin
            count <= count + 1;
          end
        end
      endcase
    end
  end

  assign sum = sum_int;

endmodule