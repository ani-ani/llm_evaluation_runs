module sequence_counter (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [15:0] m,
  input reg [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // 2D array T[1:16][1:15]
  reg [15:0] T [1:16][1:15];

  // State machine parameters
  parameter IDLE = 2'b00;
  parameter PROCESS = 2'b01;
  parameter DONE = 2'b10;

  // State and counters
  reg [1:0] state;
  reg [4:0] i_counter; // i from 1 to 16, 5 bits
  reg [3:0] j_counter; // j from 1 to 15, 4 bits

  always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      i_counter <= 0;
      j_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESS;
            j_counter <= 1;
            i_counter <= 1;
          end
        end
        PROCESS: begin
          // Compute T[i][j] for current i and j
          if (j_counter == 1) begin
            T[i_counter][j_counter] <= i_counter;
          end else if (i_counter < j_counter) begin
            T[i_counter][j_counter] <= 0;
          end else begin
            T[i_counter][j_counter] <= T[i_counter-1][j_counter] + T[i_counter/2][j_counter-1];
          end

          // Update counters
          if (j_counter < n) begin
            if (i_counter < m) begin
              i_counter <= i_counter + 1;
            end else begin
              j_counter <= j_counter + 1;
              i_counter <= 1;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          result <= T[m][n];
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule