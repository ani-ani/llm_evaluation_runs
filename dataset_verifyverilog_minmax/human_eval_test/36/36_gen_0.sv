module seven_counter (
  input clk,
  input rst_n,
  input start,
  input [9:0] n,
  output reg [7:0] count,
  output reg done
);

  reg [9:0] i;
  reg [1:0] state;
  parameter IDLE = 2'b00, COUNTING = 2'b01, DONE = 2'b10;

  // Lookup table for count of 7's in 10-bit numbers
  reg [2:0] count_7s_table [0:1023];
  genvar k;
  generate
    for (k=0; k<1024; k++) begin : init_table
      wire [9:0] num = k;
      wire [3:0] d0 = num % 10;
      wire [3:0] d1 = (num / 10) % 10;
      wire [3:0] d2 = (num / 100) % 10;
      wire [3:0] d3 = num / 1000;
      assign count_7s_table[k] = (d0==7) + (d1==7) + (d2==7) + (d3==7);
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      i <= 0;
      done <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNTING;
            count <= 0;
            i <= 0;
            done <= 0;
          end
        end
        COUNTING: begin
          if (i == n) begin
            done <= 1;
            state <= DONE;
          end
          else begin
            if ((i % 11 == 0) || (i % 13 == 0)) begin
              count <= count + count_7s_table[i];
            end
            i <= i + 1;
          end
        end
        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
            count <= 0;
            i <= 0;
          end
        end
      endcase
    end
  end

endmodule
