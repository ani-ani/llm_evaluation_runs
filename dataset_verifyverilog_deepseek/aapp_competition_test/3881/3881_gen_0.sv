module string_compressor(
  input clk,
  input rst_n,
  input start,
  output reg [15:0] result,
  output reg done
);

  localparam N = 6; // Manually adjust per test case (2-6)
  localparam MAX_COUNT = (6**N) - 1;
  localparam A_CHAR = 3'b000; // Change if 'a' encoding differs

  // FSM states
  typedef enum {IDLE, INIT, GENERATE_STRING, START_COMPRESS, COMPRESS_STEP, CHECK, NEXT_STRING, DONE_STATE} state_t;
  state_t state;

  reg [15:0] string_counter;
  reg [17:0] current_str;
  reg [2:0] current_length;
  reg [2:0] step_counter;
  reg [15:0] result_reg;

  // ROM function (replace case items with actual rules)
  function automatic [2:0] rom(input [2:0] c3bittle [17:0] current_str,
    .done_reg(done_reg),
    .result(result)
  );
    case ({current_str[17:15], current_str[14:12]})
      6'b000000: rom = 3'b000;
      default: rom = 3'b000; // Replace with all 36 rules
    endcase
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'b0;
      done <= 1'b0;
      string_counter <= 16'b0;
      current_str <= 18'b0;
      current_length <= 3'b0;
      step_counter <= 3'b0;
      result_reg <= 16'b0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) state <= INIT;
        end

        INIT: begin
          result_reg <= 16'b0;
          string_counter <= 16'b0;
          state <= GENERATE_STRING;
        end

        GENERATE_STRING: begin
          current_str <= string_counter << (18 - 3*N); // Left-align string
          current_length <= N;
          state <= START_COMPRESS;
        end

        START_COMPRESS: begin
          step_counter <= 3'b0;
          state <= COMPRESS_STEP;
        end

        COMPRESS_STEP: begin
          if (step_counter < (N-1)) begin
            // Apply leftmost compression
            current_str[17:15] <= rom(current_str[17:15], current_str[14:12]);
            current_str[14:0] <= current_str[11:0] << 3; // Shift remaining
            current_length <= current_length - 1;
            step_counter <= step_counter + 1;
          end else begin
            state <= CHECK;
          end
        end

        CHECK: begin
          if (current_str[17:15] == A_CHAR)
            result_reg <= result_reg + 1;
          state <= NEXT_STRING;
        end

        NEXT_STRING: begin
          if (string_counter == MAX_COUNT)
            state <= DONE_STATE;
          else begin
            string_counter <= string_counter + 1;
            state <= GENERATE_STRING;
          end
        end

        DONE_STATE: begin
          result <= result_reg;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule