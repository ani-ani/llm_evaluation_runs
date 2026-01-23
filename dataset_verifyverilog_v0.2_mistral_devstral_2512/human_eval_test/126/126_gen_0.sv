module is_sorted (
  input clk,
  input rst_n,
  input start,
  input [2:0] len,
  input [7:0] data_in,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD_FIRST,
    COMPARE,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] index = 0;
  reg [7:0] prev_data = 0;
  reg [1:0] dup_count = 0;
  reg [2:0] counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      prev_data <= 0;
      dup_count <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_FIRST;
            counter <= 0;
            result <= 0;
            done <= 0;
          end
        end

        LOAD_FIRST: begin
          if (len == 0) begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end else begin
            prev_data <= data_in;
            index <= 1;
            dup_count <= 0;
            counter <= 1;
            state <= COMPARE;
          end
        end

        COMPARE: begin
          if (counter < len) begin
            if (data_in == prev_data) begin
              dup_count <= dup_count + 1;
              if (dup_count > 2) begin
                result <= 0;
                done <= 1;
                state <= DONE;
              end
            end else begin
              dup_count <= 0;
              if (data_in < prev_data) begin
                result <= 0;
                done <= 1;
                state <= DONE;
              end
            end
            prev_data <= data_in;
            counter <= counter + 1;
          end else begin
            result <= 1;
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          // Stay in DONE until reset
        end
      endcase
    end
  end

endmodule