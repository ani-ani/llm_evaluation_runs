module packet_solver (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg [4:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [15:0] n_reg;
  reg [4:0] count_reg;
  reg [3:0] shift_counter;

  // Default assignments
  assign result = count_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      n_reg <= 0;
      count_reg <= 0;
      shift_counter <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATING;
          n_reg = n;
          count_reg = 0;
          shift_counter = 0;
          done = 0;
        end
      end
      CALCULATING: begin
        if (n_reg == 0) begin
          next_state = DONE;
        end else begin
          next_state = CALCULATING;
        end
      end
      DONE: begin
        if (start) begin
          next_state = CALCULATING;
          n_reg = n;
          count_reg = 0;
          shift_counter = 0;
          done = 0;
        end
      end
    endcase
  end

  // Calculation logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg <= 0;
      count_reg <= 0;
      shift_counter <= 0;
    end else if (current_state == CALCULATING) begin
      if (n_reg != 0) begin
        n_reg <= n_reg >> 1;
        count_reg <= count_reg + 1;
        shift_counter <= shift_counter + 1;
      end
    end else if (current_state == DONE) begin
      done <= 1;
    end
  end

endmodule