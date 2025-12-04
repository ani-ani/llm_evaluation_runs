module odd_collatz(
  input clk, 
  input rst_n, 
  input start, 
  input [7:0] n, 
  output reg done, 
  output reg [9:0] odd_mem [0:15], 
  output reg [4:0] count
);

  reg [1:0] state;
  parameter IDLE=0, COMPUTE=1, DONE=2;
  reg [7:0] step_count;
  reg [63:0] current;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      count <= 0;
      step_count <= 0;
      current <= 0;
      // Clear odd_mem array
      for (int i = 0; i < 16; i++) begin
        odd_mem[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          step_count <= 0;
          current <= 0;
          if (start) begin
            state <= COMPUTE;
            current <= {56'b0, n}; // Zero-extend n to 64 bits
            count <= 0;
          end
        end
        COMPUTE: begin
          if (current == 1) begin
            // Sequence complete, add final 1 if space
            if (count < 16) begin
              odd_mem[count] <= 1;
              count <= count + 1;
            end
            state <= DONE;
            done <= 1;
          end else if (step_count == 8'd128) begin
            // Max cycles reached, stop
            state <= DONE;
            done <= 1;
          end else begin
            // Process next Collatz step
            if (current[0] == 1) begin // odd
              if (count < 16) begin
                odd_mem[count] <= current[9:0]; // Store lower 10 bits
                count <= count + 1;
              end
              current <= current * 3 + 1;
            end else begin // even
              current <= current / 2;
            end
            step_count <= step_count + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule