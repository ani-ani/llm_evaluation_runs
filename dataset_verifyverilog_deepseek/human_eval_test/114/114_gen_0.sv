module min_subarray_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0][15:0] nums,
  output reg [15:0] min_sum,
  output reg done
);

  // State encoding
  typedef enum reg [2:0] {
    IDLE    = 3'b000,
    INIT1   = 3'b001,
    INIT2   = 3'b010,
    PROCESS = 3'b011,
    DONE    = 3'b100
  } state_t;

  reg [7:0][15:0] latched_nums;
  reg [2:0] index;
  reg signed [15:0] current_min;
  reg signed [15:0] global_min;
  state_t state;

  // Combinational nets for min operations
  wire signed [15:0] current_element = $signed(latched_nums[index]);
  wire signed [15:0] sum_val = $signed(current_min) + current_element;
  wire signed [15:0] new_current_min = (sum_val < current_element) ? sum_val : current_element;
  wire signed [15:0] new_global_min = (new_current_min < global_min) ? new_current_min : global_min;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_sum <= 16'sd0;
      current_min <= 16'sd0;
      global_min <= 16'sd0;
      latched_nums <= '0;
      index <= 3'd0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= INIT1;
          end
        end

        INIT1: begin
          latched_nums <= nums;
          state <= INIT2;
        end

        INIT2: begin
          current_min <= $signed(nums[0]);
          global_min <= $signed(nums[0]);
          index <= 3'd1;
          state <= PROCESS;
        end

        PROCESS: begin
          current_min <= new_current_min;
          global_min <= new_global_min;
          if (index == 3'd7) begin
            state <= DONE;
          end
          else begin
            index <= index + 3'd1;
          end
        end

        DONE: begin
          min_sum <= global_min;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule