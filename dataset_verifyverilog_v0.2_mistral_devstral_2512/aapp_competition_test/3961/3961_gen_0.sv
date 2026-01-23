module maze_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] p_i,
  input [2:0] current_room_index,
  output reg [31:0] total_moves,
  output reg done
);

  parameter MOD = 32'd1000000007;
  parameter IDLE = 2'b00;
  parameter CALC = 2'b01;
  parameter DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [31:0] dp [0:8];
  reg [2:0] room_counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      room_counter <= 0;
      done <= 0;
      total_moves <= 0;
      dp[0] <= 0;
      for (int i = 1; i <= 8; i = i + 1) begin
        dp[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC;
            room_counter <= 1;
            dp[0] <= 0;
            dp[1] <= 2;
          end
        end
        CALC: begin
          if (room_counter == current_room_index) begin
            state <= DONE;
            total_moves <= dp[room_counter];
            done <= 1;
          end else begin
            if (p_i == room_counter) begin
              dp[room_counter + 1] <= (dp[room_counter] + 2) % MOD;
            end else begin
              dp[room_counter + 1] <= (2 + 2 * dp[room_counter] - dp[p_i - 1] + MOD) % MOD;
            end
            room_counter <= room_counter + 1;
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