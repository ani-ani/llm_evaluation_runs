module garbage_disposal (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] k,
  input [7:0] a_i,
  output reg [31:0] total_bags,
  output reg done,
  output reg [4:0] day_index
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    FETCH_DAY,
    PROCESS_DAY,
    FINISHED
  } state_t;

  state_t current_state, next_state;
  reg [7:0] carry;
  reg [31:0] bags_accum;
  reg [4:0] current_day;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      total_bags <= 32'b0;
      done <= 1'b0;
      day_index <= 5'b0;
      carry <= 8'b0;
      bags_accum <= 32'b0;
      current_day <= 5'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = FETCH_DAY;
      end
      FETCH_DAY: begin
        next_state = PROCESS_DAY;
      end
      PROCESS_DAY: begin
        if (current_day == n - 1) next_state = FINISHED;
        else next_state = FETCH_DAY;
      end
      FINISHED: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        total_bags = 32'b0;
        done = 1'b0;
        day_index = 5'b0;
      end
      FETCH_DAY: begin
        day_index = current_day;
        done = 1'b0;
      end
      PROCESS_DAY: begin
        day_index = current_day;
        done = 1'b0;
      end
      FINISHED: begin
        total_bags = bags_accum;
        done = 1'b1;
        day_index = current_day;
      end
      default: begin
        total_bags = 32'b0;
        done = 1'b0;
        day_index = 5'b0;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      carry <= 8'b0;
      bags_accum <= 32'b0;
      current_day <= 5'b0;
    end else begin
      case (current_state)
        FETCH_DAY: begin
          // No action in FETCH_DAY, just move to PROCESS_DAY
        end
        PROCESS_DAY: begin
          // Calculate current garbage
          reg [15:0] current_garbage = a_i + carry;
          reg [7:0] bags_today = current_garbage / k;
          reg [7:0] new_carry = current_garbage % k;

          // Accumulate bags
          bags_accum <= bags_accum + bags_today;

          // Update carry
          carry <= new_carry;

          // Increment day counter
          if (current_day == n - 1) begin
            // Last day: add extra bag if carry exists
            if (new_carry != 0) bags_accum <= bags_accum + 1;
          end else begin
            current_day <= current_day + 1;
          end
        end
        default: begin
          // Reset accumulators when not in processing states
          if (current_state == IDLE && start) begin
            carry <= 8'b0;
            bags_accum <= 32'b0;
            current_day <= 5'b0;
          end
        end
      endcase
    end
  end

endmodule