module toy_train (
  input clk,
  input rst_n,
  input start,
  input valid_input,
  input [2:0] a,
  input [2:0] b,
  output reg output_valid,
  output reg [15:0] result,
  output reg busy
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam RECV_INPUTS = 3'b001;
  localparam CALCULATE = 3'b010;
  localparam OUTPUT = 3'b100;

  // Internal registers
  reg [2:0] state;
  reg [2:0] current_start;
  reg [2:0] i, j;
  reg [3:0] count [0:7];
  reg [2:0] min_dist [0:7];
  reg [15:0] time_i;
  reg [15:0] max_time;
  reg [2:0] dist;
  reg [2:0] n;
  reg [3:0] total_candies;

  // Initialize arrays on reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_start <= 0;
      i <= 0;
      j <= 0;
      output_valid <= 0;
      result <= 0;
      busy <= 0;
      n <= 3; // Default to minimum n
      total_candies <= 0;
      for (int k = 0; k < 8; k = k + 1) begin
        count[k] <= 0;
        min_dist[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (valid_input) begin
            state <= RECV_INPUTS;
            busy <= 1;
          end else if (start) begin
            state <= CALCULATE;
            busy <= 1;
            current_start <= 0;
          end
        end
        RECV_INPUTS: begin
          if (valid_input) begin
            // Update count and min_dist
            count[a] <= count[a] + 1;
            if (count[a] == 1) begin
              min_dist[a] <= b;
            end else begin
              if (b < min_dist[a]) begin
                min_dist[a] <= b;
              end
            end
            total_candies <= total_candies + 1;
            // Update n based on max station index
            if (a > n || b > n) begin
              n <= (a > b) ? a + 1 : b + 1;
            end
          end else begin
            state <= IDLE;
            busy <= 0;
          end
        end
        CALCULATE: begin
          if (i == n) begin
            state <= OUTPUT;
            result <= max_time;
            output_valid <= 1;
          end else begin
            if (count[i] > 0) begin
              // Calculate dist(current_start, i)
              if (current_start <= i) begin
                dist <= i - current_start;
              end else begin
                dist <= (n - current_start) + i;
              end
              // Calculate time_i
              time_i <= dist + min_dist[i] + (count[i] - 1) * n;
              if (time_i > max_time) begin
                max_time <= time_i;
              end
            end
            i <= i + 1;
          end
        end
        OUTPUT: begin
          if (current_start == n - 1) begin
            state <= IDLE;
            output_valid <= 0;
            busy <= 0;
            i <= 0;
            max_time <= 0;
          end else begin
            current_start <= current_start + 1;
            i <= 0;
            max_time <= 0;
            state <= CALCULATE;
            output_valid <= 0;
          end
        end
      endcase
    end
  end

endmodule