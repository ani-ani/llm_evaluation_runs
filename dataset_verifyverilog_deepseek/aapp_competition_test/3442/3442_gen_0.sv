module sheldon_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0] num,
  output reg done,
  output reg is_sheldon
);

  typedef enum logic [2:0] {
    IDLE,
    FIRST_RUN_1,
    MEASURE_0,
    MEASURE_1,
    CHECK,
    DONE
  } state_t;

  state_t current_state;
  reg [15:0] shift_reg;
  reg [4:0] bit_counter;
  reg [4:0] run_length;
  reg [4:0] N, M;
  reg valid;
  reg first_zero_run;
  reg expecting_ones;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      is_sheldon <= 1'b0;
      shift_reg <= 16'b0;
      bit_counter <= 5'b0;
      run_length <= 5'b0;
      N <= 5'b0;
      M <= 5'b0;
      valid <= 1'b1;
      first_zero_run <= 1'b1;
      expecting_ones <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          is_sheldon <= 1'b0;
          if (start) begin
            shift_reg <= num;
            bit_counter <= 5'b0;
            run_length <= 5'b0;
            N <= 5'b0;
            M <= 5'b0;
            valid <= 1'b1;
            first_zero_run <= 1'b1;
            expecting_ones <= 1'b0;
            current_state <= FIRST_RUN_1;
          end
        end

        FIRST_RUN_1: begin
          bit_counter <= bit_counter + 1;
          if (shift_reg[15]) begin
            run_length <= run_length + 1;
          end else begin
            if (run_length) begin
              N <= run_length;
              run_length <= 5'b0;
              current_state <= MEASURE_0;
              if (shift_reg[14:0] == 15'b0) current_state <= CHECK;
            end else begin
              if (bit_counter == 15) valid <= 1'b0;
            end
          end
          if (bit_counter == 15) current_state <= CHECK;
          shift_reg <= shift_reg << 1;
        end

        MEASURE_0: begin
          bit_counter <= bit_counter + 1;
          if (!shift_reg[15]) begin
            run_length <= run_length + 1;
          end else begin
            if (first_zero_run) begin
              M <= run_length;
              first_zero_run <= 1'b0;
            end else if (run_length != M) begin
              valid <= 1'b0;
            end
            run_length <= 5'b1;
            expecting_ones <= 1'b1;
            current_state <= MEASURE_1;
          end
          if (bit_counter == 15) begin
            if (first_zero_run) M <= run_length;
            else if (run_length != M) valid <= 1'b0;
            current_state <= CHECK;
          end
          shift_reg <= shift_reg << 1;
        end

        MEASURE_1: begin
          bit_counter <= bit_counter + 1;
          if (shift_reg[15]) begin
            run_length <= run_length + 1;
          end else begin
            if (run_length != N) begin
              valid <= 1'b0;
            end
            run_length <= 5'b1;
            expecting_ones <= 1'b0;
            current_state <= MEASURE_0;
          end
          if (bit_counter == 15) begin
            if (run_length != N) valid <= 1'b0;
            current_state <= CHECK;
          end
          shift_reg <= shift_reg << 1;
        end

        CHECK: begin
          if (N == 0) valid <= 1'b0;
          if (expecting_ones && run_length != N && run_length != 0) valid <= 1'b0;
          if (!expecting_ones && first_zero_run && run_length != 0) valid <= 1'b0;
          done <= 1'b1;
          is_sheldon <= valid;
          current_state <= DONE;
        end

        DONE: begin
          done <= 1'b0;
          is_sheldon <= 1'b0;
          current_state <= IDLE;
        end
      endcase
    end
  end

endmodule