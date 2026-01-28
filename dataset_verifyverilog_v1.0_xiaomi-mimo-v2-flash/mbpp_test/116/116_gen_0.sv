module tuple_to_int(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [1:0] len,
  input wire [3:0] nums [0:3],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE    = 3'd0;
  localparam [2:0] CALC_0  = 3'd1;
  localparam [2:0] CALC_1  = 3'd2;
  localparam [2:0] CALC_2  = 3'd3;
  localparam [2:0] CALC_3  = 3'd4;
  localparam [2:0] DONE    = 3'd5;

  // Internal registers
  reg [2:0] state, next_state;
  reg [15:0] result_reg, next_result;
  reg [1:0] idx, next_idx;
  reg [15:0] temp_result;

  // Counter to prevent infinite loops
  reg [3:0] cycle_count;
  localparam [3:0] MAX_CYCLES = 4'd10;

  // Next state and output logic
  always @(*) begin
    next_state = state;
    next_result = result_reg;
    next_idx = idx;
    temp_result = result_reg;

    case (state)
      IDLE: begin
        if (start) begin
          next_result = 16'd0;
          next_idx = 2'd0;
          next_state = CALC_0;
        end
      end

      CALC_0: begin
        if (len > 2'd0) begin
          temp_result = result_reg * 16'd10 + {12'd0, nums[0]};
          next_result = temp_result;
          next_idx = idx + 2'd1;
        end
        next_state = CALC_1;
      end

      CALC_1: begin
        if (len > 2'd1 && idx <= 2'd1) begin
          temp_result = result_reg * 16'd10 + {12'd0, nums[1]};
          next_result = temp_result;
          next_idx = idx + 2'd1;
        end
        next_state = CALC_2;
      end

      CALC_2: begin
        if (len > 2'd2 && idx <= 2'd2) begin
          temp_result = result_reg * 16'd10 + {12'd0, nums[2]};
          next_result = temp_result;
          next_idx = idx + 2'd1;
        end
        next_state = CALC_3;
      end

      CALC_3: begin
        if (len == 2'd3) begin
          next_state = DONE;
        end else if (len == 2'd4 && idx <= 2'd3) begin
          temp_result = result_reg * 16'd10 + {12'd0, nums[3]};
          next_result = temp_result;
          next_state = DONE;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result_reg <= 16'd0;
      result <= 16'd0;
      done <= 1'b0;
      idx <= 2'd0;
      cycle_count <= 4'd0;
    end else begin
      cycle_count <= cycle_count + 4'd1;
      
      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_count <= 4'd0;
          if (start) begin
            state <= CALC_0;
            result_reg <= 16'd0;
            idx <= 2'd0;
          end
        end

        CALC_0: begin
          if (len > 2'd0) begin
            result_reg <= result_reg * 16'd10 + {12'd0, nums[0]};
            idx <= idx + 2'd1;
          end
          state <= CALC_1;
        end

        CALC_1: begin
          if (len > 2'd1 && idx <= 2'd1) begin
            result_reg <= result_reg * 16'd10 + {12'd0, nums[1]};
            idx <= idx + 2'd1;
          end
          state <= CALC_2;
        end

        CALC_2: begin
          if (len > 2'd2 && idx <= 2'd2) begin
            result_reg <= result_reg * 16'd10 + {12'd0, nums[2]};
            idx <= idx + 2'd1;
          end
          state <= CALC_3;
        end

        CALC_3: begin
          if (len == 2'd4 && idx <= 2'd3) begin
            result_reg <= result_reg * 16'd10 + {12'd0, nums[3]};
          end
          state <= DONE;
        end

        DONE: begin
          result <= result_reg;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase

      // Safety timeout
      if (cycle_count >= MAX_CYCLES && state != IDLE) begin
        state <= IDLE;
        done <= 1'b0;
      end
    end
  end

endmodule