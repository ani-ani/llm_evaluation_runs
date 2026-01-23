module fluttershy_scheduling (
  input clk,
  input rst_n,
  input start,
  input [3:0][31:0] config_p_in,
  input [3:0][31:0] config_r_in,
  input [4:0] customer_type_in,
  input [31:0] customer_time_in,
  input in_valid,
  output reg in_ready,
  output reg [31:0] result,
  output reg result_valid
);

  // Parameters
  localparam M = 4; // Max Clothing Types
  localparam N = 16; // Max Customers
  localparam NONE = M; // Index for 'no clothing'

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    WAIT_FOR_NEXT,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;
  logic [31:0] dp_state [0:M]; // dp_state[0..M-1] for clothing types, dp_state[M] for 'none'
  logic [31:0] min_time;
  logic [3:0] served_count;
  logic [4:0] current_customer_type;
  logic [31:0] current_customer_time;
  logic [3:0] customer_index;

  // State transition logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      in_ready <= 0;
      result_valid <= 0;
      served_count <= 0;
      customer_index <= 0;
      for (int i = 0; i < M; i = i + 1) begin
        dp_state[i] <= 32'hFFFFFFFF; // Initialize to infinity
      end
      dp_state[M] <= 0; // 'none' state starts at 0
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    in_ready = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          in_ready = 1;
        end
      end

      PROCESSING: begin
        if (in_valid) begin
          next_state = WAIT_FOR_NEXT;
          current_customer_type = customer_type_in;
          current_customer_time = customer_time_in;
        end else begin
          in_ready = 1;
        end
      end

      WAIT_FOR_NEXT: begin
        next_state = PROCESSING;
        in_ready = 1;
      end

      DONE: begin
        result_valid = 1;
      end

      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else if (current_state == WAIT_FOR_NEXT) begin
      // Calculate new costs
      min_time = 32'hFFFFFFFF;
      for (int j = 0; j <= M; j = j + 1) begin
        if (dp_state[j] == 32'hFFFFFFFF) continue;

        if (j == current_customer_type) begin
          // Case 1: No change needed
          if (dp_state[j] <= current_customer_time && dp_state[j] < min_time) begin
            min_time = dp_state[j];
          end
        end else if (j == NONE) begin
          // Case 2: From 'none' to current type
          logic [31:0] new_time = dp_state[j] + config_p_in[current_customer_type];
          if (new_time <= current_customer_time && new_time < min_time) begin
            min_time = new_time;
          end
        end else begin
          // Case 3: From another type to current type
          logic [31:0] new_time = dp_state[j] + config_r_in[j] + config_p_in[current_customer_type];
          if (new_time <= current_customer_time && new_time < min_time) begin
            min_time = new_time;
          end
        end
      end

      // Update state if valid transition found
      if (min_time != 32'hFFFFFFFF) begin
        dp_state[current_customer_type] = min_time;
        served_count = served_count + 1;
      end

      // Check if all customers processed
      customer_index = customer_index + 1;
      if (customer_index == N || current_customer_type == 0) begin
        next_state = DONE;
        result = served_count;
      end
    end
  end

endmodule