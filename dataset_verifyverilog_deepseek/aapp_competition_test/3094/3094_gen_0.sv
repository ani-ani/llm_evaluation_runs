module permutation_square_count(
  input clk, 
  input rst_n, 
  input start, 
  input [2:0] n, 
  input [2:0] t_0, 
  input [2:0] t_1, 
  input [2:0] t_2, 
  input [2:0] t_3, 
  input [2:0] t_4, 
  input [2:0] t_5, 
  input [2:0] t_6, 
  input [2:0] t_7, 
  output reg [31:0] result, 
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    INIT,
    FIND_CYCLES,
    CYCLE_DETECT,
    COMPUTE,
    FINISH
  } state_t;

  state_t current_state, next_state;
  reg [7:0] visited;
  reg [2:0] t [0:7];
  reg [2:0] current_element;
  reg [2:0] current_index;
  reg [3:0] cycle_len;
  reg [2:0] start_element;
  reg [5:0] cycle_counter;
  reg [31:0] product;
  reg [5:0] total_cycles;

  parameter MOD = 32'd1000000007;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done <= 0;
          cycle_counter <= 0;
          if (start) begin
            next_state = INIT;
          end
        end

        INIT: begin
          visited <= 8'b0;
          result <= 0;
          product <= 1;
          done <= 0;
          current_element <= 0;
          t[0] <= t_0;
          t[1] <= t_1;
          t[2] <= t_2;
          t[3] <= t_3;
          t[4] <= t_4;
          t[5] <= t_5;
          t[6] <= t_6;
          t[7] <= t_7;
          total_cycles <= 8 + (n << 2);
          next_state <= FIND_CYCLES;
        end

        FIND_CYCLES: begin
          if (current_element < n) begin
            if (!visited[current_element]) begin
              visited[current_element] <= 1'b1;
              start_element <= current_element;
              current_index <= t[current_element];
              cycle_len <= 1;
              next_state <= CYCLE_DETECT;
            end else begin
              current_element <= current_element + 1;
            end
          end else begin
            next_state <= FINISH;
          end
        end

        CYCLE_DETECT: begin
          if (current_index == start_element) begin
            next_state <= COMPUTE;
          end else if (!visited[current_index]) begin
            visited[current_index] <= 1'b1;
            cycle_len <= cycle_len + 1;
            current_index <= t[current_index];
          end else begin
            next_state <= COMPUTE;
          end
        end

        COMPUTE: begin
          if (cycle_len[0] == 1'b1) begin
            product <= (product * cycle_len) % MOD;
          end else begin
            if (cycle_len % 2 == 0) begin
              product <= (product * (cycle_len/2)) % MOD;
            end else begin
              product <= 0;
            end
          end
          current_element <= current_element + 1;
          next_state <= FIND_CYCLES;
        end

        FINISH: begin
          result <= product;
          done <= 1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase

      if (current_state != IDLE && current_state != INIT) cycle_counter <= cycle_counter + 1;
      if (cycle_counter >= total_cycles - 1 && current_state != IDLE) begin
        result <= product;
        done <= 1;
        next_state <= IDLE;
      end
    end
  end

  always_comb begin
    case (current_state)
      IDLE: next_state = start ? INIT : IDLE;
      default: ;
    endcase
  end

endmodule