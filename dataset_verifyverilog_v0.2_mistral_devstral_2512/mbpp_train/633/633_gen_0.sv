module pair_xor_sum (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] arr [0:7],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state;
  reg [2:0] i;
  reg [2:0] j;
  reg [15:0] sum;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            i <= 0;
            j <= 0;
            sum <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (i < n && j < n) begin
            if (i < j) begin
              sum <= sum + (arr[i] ^ arr[j]);
            end
            if (j == n-1) begin
              i <= i + 1;
              j <= 0;
            end else begin
              j <= j + 1;
            end
            if (i == n-1 && j == n-1) begin
              state <= DONE;
            end
          end
        end
        DONE: begin
          result <= sum;
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule