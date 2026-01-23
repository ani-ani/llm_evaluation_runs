module move_one_ball (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_SORTED,
    COUNT_DROPS,
    VALIDATE,
    DONE
  } state_t;

  state_t state;
  reg [2:0] index;
  reg [2:0] drop_count;
  reg is_sorted;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      drop_count <= 0;
      is_sorted <= 1;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_SORTED;
            index <= 0;
            is_sorted <= 1;
            done <= 0;
          end
        end
        CHECK_SORTED: begin
          if (index < 7) begin
            if (arr[index] > arr[index + 1]) begin
              is_sorted <= 0;
            end
            index <= index + 1;
          end else begin
            if (arr[7] > arr[0]) begin
              is_sorted <= 0;
            end
            state <= COUNT_DROPS;
            index <= 0;
            drop_count <= 0;
          end
        end
        COUNT_DROPS: begin
          if (index < 7) begin
            if (arr[index] > arr[index + 1]) begin
              drop_count <= drop_count + 1;
            end
            index <= index + 1;
          end else begin
            if (arr[7] > arr[0]) begin
              drop_count <= drop_count + 1;
            end
            state <= VALIDATE;
          end
        end
        VALIDATE: begin
          if (is_sorted || (drop_count == 1)) begin
            result <= 1;
          end else begin
            result <= 0;
          end
          state <= DONE;
        end
        DONE: begin
          done <= 1;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule