module sequence_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [29:0] result,
  output reg done
);
  reg [29:0] dp_array [0:7];
  localparam IDLE = 2'd0;
  localparam COMPUTE = 2'd1;
  localparam DONE = 2'd2;
  reg [1:0] state;
  reg [2:0] counter;
  localparam MOD = 30'd1000000007;

  always @(posedge clk or negedge rst_n) 
  begin
    if (!rst_n)
      begin
        state <= IDLE;
        counter <= 0;
        result <= 0;
        done <= 0;
      end
    else
      begin
        case (state)
          IDLE: 
          begin
            if (start)
              begin
                state <= COMPUTE;
                counter <= 0;
                done <= 0;
              end
            else
              begin
                state <= IDLE;
                counter <= 0;
                done <= 0;
              end
          end
          COMPUTE:
          begin
            if (counter < 7)
              begin
                state <= COMPUTE;
                counter <= counter + 1;
                if (counter == 0)
                  dp_array[0] <= 1;
                else if (counter == 1)
                  dp_array[1] <= 4;
                else
                  begin
                    dp_array[counter] <= ( (dp_array[counter-1] * 2) + dp_array[counter-2] ) % MOD;
                  end
              end
            else
              begin
                state <= DONE;
                result <= dp_array[n-1];
                done <= 1;
                counter <= 0;
              end
          end
          DONE:
          begin
            if (start)
              begin
                state <= COMPUTE;
                counter <= 0;
                done <= 0;
              end
            else
              begin
                state <= DONE;
              end
          end
        endcase
      end
  end

endmodule