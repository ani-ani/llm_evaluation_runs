module mirko_game_solver(
  input clk,                      // system clock
  input rst_n,                    // active-low reset
  input start,                    // pulse high to start processing
  input [7:0] K,                  // window size [1-150]
  input [7:0] L,                  // required happy count [0-K]
  input [7:0] M,                  // happy threshold [1-150]
  output reg [15:0] result,       // solution (start number or -1)
  output reg done                  // high when result valid
);

  // State definitions
  parameter [2:0]
    IDLE      = 3'd0,
    CHECK_S   = 3'd1,
    CHECK_NUM = 3'd2,
    CHECK_PRIME = 3'd3,
    POST_PRIME  = 3'd4,
    UPDATE    = 3'd5,
    DONE      = 3'd6;

  reg [2:0] state, next_state;
  reg [15:0] S;          // Current candidate start number
  reg [7:0] num_idx;     // Current index in window [0-K-1]
  reg [16:0] current_num; // Current number being checked (S + num_idx)
  reg [7:0] happy_count; // Count of happy numbers in window
  reg [15:0] divisor;    // Divisor for prime check
  reg is_prime;          // Prime check result
  wire [16:0] divisor_sq = divisor * divisor; // Divisor squared

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'd0;
      done <= 1'b0;
      S <= 16'd1;
      num_idx <= 8'd0;
      happy_count <= 8'd0;
      divisor <= 16'd0;
      is_prime <= 1'b0;
      current_num <= 17'd0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            S <= 16'd1;
            num_idx <= 8'd0;
            happy_count <= 8'd0;
            state <= CHECK_S;
          end
        end

        CHECK_S: begin
          current_num <= S + num_idx;
          state <= CHECK_NUM;
        end

        CHECK_NUM: begin
          if (current_num <= {9'd0, M}) begin
            happy_count <= happy_count + 1'b1;
            if (num_idx == (K - 1)) begin
              state <= UPDATE;
            end
            else begin
              num_idx <= num_idx + 1'b1;
              state <= CHECK_S;
            end
          end
          else begin
            divisor <= 16'd2;
            state <= CHECK_PRIME;
          end
        end

        CHECK_PRIME: begin
          if (divisor_sq > current_num) begin
            is_prime <= 1'b1;
            state <= POST_PRIME;
          end
          else if (current_num % divisor == 0) begin
            is_prime <= 1'b0;
            state <= POST_PRIME;
          end
          else begin
            divisor <= divisor + 1'b1;
          end
        end

        POST_PRIME: begin
          if (is_prime)
            happy_count <= happy_count + 1'b1;
          
          if (num_idx == (K - 1)) begin
            state <= UPDATE;
          end
          else begin
            num_idx <= num_idx + 1'b1;
            state <= CHECK_S;
          end
        end

        UPDATE: begin
          if (happy_count == L) begin
            result <= S;
            done <= 1'b1;
            state <= DONE;
          end
          else begin
            if (S == 16'hFFFF) begin
              result <= 16'hFFFF;
              done <= 1'b1;
              state <= DONE;
            end
            else begin
              S <= S + 1'b1;
              num_idx <= 8'd0;
              happy_count <= 8'd0;
              state <= CHECK_S;
            end
          end
        end

        DONE: begin
          if (start) begin
            S <= 16'd1;
            num_idx <= 8'd0;
            happy_count <= 8'd0;
            done <= 1'b0;
            state <= CHECK_S;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule