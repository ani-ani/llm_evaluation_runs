module tuple_trimmer (
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] tuple_len,
  input [4:0] data_in [0:3],
  output reg [2:0] out_len,
  output reg [4:0] result_0,
  output reg [4:0] result_1,
  output reg [4:0] result_2,
  output reg [4:0] result_3,
  output reg [4:0] result_4,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_K,
    COMPUTE,
    WRITE_OUT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] k_reg;
  reg [2:0] tuple_len_reg;
  reg [4:0] data_reg [0:3];
  reg [2:0] out_len_reg;
  reg [4:0] result_reg [0:4];
  reg done_reg;
  reg [2:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      k_reg <= 0;
      tuple_len_reg <= 0;
      out_len_reg <= 0;
      done_reg <= 0;
      counter <= 0;
      result_reg[0] <= 0;
      result_reg[1] <= 0;
      result_reg[2] <= 0;
      result_reg[3] <= 0;
      result_reg[4] <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          k_reg <= 0;
          tuple_len_reg <= 0;
          out_len_reg <= 0;
          done_reg <= 0;
          counter <= 0;
        end

        READ_K: begin
          k_reg <= k;
          tuple_len_reg <= tuple_len;
          for (int i = 0; i < 4; i++) begin
            data_reg[i] <= data_in[i];
          end
        end

        COMPUTE: begin
          // Calculate output length
          out_len_reg <= (tuple_len_reg - 2*k_reg) > 0 ? (tuple_len_reg - 2*k_reg) : 0;

          // Process each tuple
          for (int i = 0; i < 4; i++) begin
            if (k_reg < tuple_len_reg - k_reg) begin
              // Valid trim operation
              case (counter)
                0: result_reg[0] <= data_reg[i][k_reg];
                1: result_reg[1] <= data_reg[i][k_reg + 1];
                2: result_reg[2] <= data_reg[i][k_reg + 2];
                3: result_reg[3] <= data_reg[i][k_reg + 3];
                4: result_reg[4] <= data_reg[i][k_reg + 4];
              endcase
            end else begin
              // Empty result
              result_reg[0] <= 0;
              result_reg[1] <= 0;
              result_reg[2] <= 0;
              result_reg[3] <= 0;
              result_reg[4] <= 0;
            end
          end

          counter <= counter + 1;
        end

        WRITE_OUT: begin
          out_len <= out_len_reg;
          result_0 <= result_reg[0];
          result_1 <= result_reg[1];
          result_2 <= result_reg[2];
          result_3 <= result_reg[3];
          result_4 <= result_reg[4];
          done_reg <= 1;
        end

        DONE: begin
          done_reg <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READ_K;
        else next_state = IDLE;
      end

      READ_K: next_state = COMPUTE;

      COMPUTE: begin
        if (counter == 5) next_state = WRITE_OUT;
        else next_state = COMPUTE;
      end

      WRITE_OUT: next_state = DONE;

      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Output assignments
  assign done = done_reg;

endmodule