module coin_ways_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] a_1, a_2, a_3,
  input [3:0] b_0, b_1, b_2, b_3,
  input [31:0] m,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam MOD = 32'd1000000007;
  localparam IDLE = 3'b000;
  localparam MOD_CHECK = 3'b001;
  localparam UPDATE_DP = 3'b010;
  localparam FINAL_CHECK = 3'b011;
  localparam DONE = 3'b100;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] coin_type = 0;
  reg [31:0] current_m;
  reg [31:0] ways [0:63];
  reg [31:0] temp_m;
  reg [31:0] temp_ways [0:63];
  reg [31:0] a_current;
  reg [3:0] b_current;

  // Initialize DP array
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      for (i = 0; i < 64; i = i + 1) begin
        ways[i] <= 0;
      end
      ways[0] <= 1;
      coin_type <= 0;
      current_m <= 0;
    end else if (start) begin
      state <= MOD_CHECK;
      done <= 0;
      result <= 0;
      for (i = 0; i < 64; i = i + 1) begin
        ways[i] <= 0;
      end
      ways[0] <= 1;
      coin_type <= 0;
      current_m <= m;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) state <= MOD_CHECK;
        end
        MOD_CHECK: begin
          if (coin_type < n - 1) begin
            // Select current ratio
            case (coin_type)
              1: a_current = a_1;
              2: a_current = a_2;
              3: a_current = a_3;
            endcase
            // Check modulo condition
            if (current_m % a_current != 0) begin
              result <= 0;
              state <= DONE;
              done <= 1;
            end else begin
              current_m <= current_m / a_current;
              state <= UPDATE_DP;
            end
          end else begin
            state <= FINAL_CHECK;
          end
        end
        UPDATE_DP: begin
          // Select current b value
          case (coin_type)
            0: b_current = b_0;
            1: b_current = b_1;
            2: b_current = b_2;
            3: b_current = b_3;
          endcase
          // Update DP array
          for (i = 0; i < 64; i = i + 1) begin
            temp_ways[i] <= 0;
          end
          for (i = 0; i < 64; i = i + 1) begin
            if (ways[i] != 0) begin
              for (integer j = 0; j <= b_current; j = j + 1) begin
                if (i + j <= 63) begin
                  temp_ways[i + j] <= (temp_ways[i + j] + ways[i]) % MOD;
                end
              end
            end
          end
          // Copy temp_ways to ways
          for (i = 0; i < 64; i = i + 1) begin
            ways[i] <= temp_ways[i];
          end
          coin_type <= coin_type + 1;
          state <= MOD_CHECK;
        end
        FINAL_CHECK: begin
          // Select current b value
          case (coin_type)
            0: b_current = b_0;
            1: b_current = b_1;
            2: b_current = b_2;
            3: b_current = b_3;
          endcase
          // Compute final result
          result <= 0;
          for (i = 0; i < 64; i = i + 1) begin
            if (i <= current_m && current_m - i <= b_current) begin
              result <= (result + ways[i]) % MOD;
            end
          end
          state <= DONE;
          done <= 1;
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