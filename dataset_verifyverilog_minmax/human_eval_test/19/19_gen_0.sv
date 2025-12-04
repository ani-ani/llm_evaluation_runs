module number_sorter (
  input clk,
  input rst_n,
  input [2:0] count,
  input [31:0] numbers,
  input start,
  output reg [31:0] sorted,
  output reg done
);

  parameter MAX_COUNT = 8;

  reg [3:0] arr [0:7];
  reg [2:0] pass, idx;
  reg [1:0] state;
  integer i;

  localparam IDLE = 2'b00;
  localparam SORTING = 2'b01;
  localparam DONE = 2'b10;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sorted <= 0;
      done <= 0;
      pass <= 0;
      idx <= 0;
      for (i = 0; i < 8; i++) begin
        arr[i] <= 0;
      end
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            for (i = 0; i < 8; i++) begin
              if (i < count) begin
                arr[i] <= numbers[4*i+3 -: 4];
              end else begin
                arr[i] <= 0;
              end
            end
            pass <= 0;
            idx <= 0;
            state <= SORTING;
          end
          done <= 0;
        end
        SORTING: begin
          if (pass < count) begin
            if (idx < count - 1 - pass) begin
              if (arr[idx] > arr[idx+1]) begin
                arr[idx] <= arr[idx+1];
                arr[idx+1] <= arr[idx];
              end
              idx <= idx + 1;
            end else begin
              pass <= pass + 1;
              idx <= 0;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          sorted <= {arr[7], arr[6], arr[5], arr[4], arr[3], arr[2], arr[1], arr[0]};
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule