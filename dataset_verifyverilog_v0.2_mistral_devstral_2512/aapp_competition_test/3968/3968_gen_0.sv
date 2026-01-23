module virus_spread (
  input clk,
  input rst_n,
  input start,
  input [7:0] init_infected,
  input [3:0] D,
  input [7:0][3:0] p_start_t,
  input [7:0][3:0] p_end_t,
  output reg [7:0] infected_status,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SIMULATING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] current_infected;
  reg [3:0] days_count;

  // Time masks (16-bit for each person)
  wire [15:0] time_mask [7:0];
  genvar i, t;
  generate
    for (i = 0; i < 8; i = i + 1) begin : time_mask_gen
      for (t = 0; t < 16; t = t + 1) begin : time_mask_bit
        assign time_mask[i][t] = (p_start_t[i] <= t) && (t <= p_end_t[i]);
      end
    end
  endgenerate

  // Contact matrix (8x8)
  wire [7:0] contact [7:0];
  genvar j, k;
  generate
    for (j = 0; j < 8; j = j + 1) begin : contact_row
      for (k = 0; k < 8; k = k + 1) begin : contact_col
        assign contact[j][k] = (time_mask[j] & time_mask[k]) != 0;
      end
    end
  endgenerate

  // New infections calculation
  wire [7:0] new_infections;
  reg [7:0] new_infections_reg;
  always @(*) begin
    new_infections_reg = 8'b0;
    for (i = 0; i < 8; i = i + 1) begin
      if (current_infected[i]) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (contact[i][j] && !current_infected[j]) begin
            new_infections_reg[j] = 1'b1;
          end
        end
      end
    end
  end
  assign new_infections = new_infections_reg;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_infected <= 8'b0;
      days_count <= 4'b0;
      infected_status <= 8'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          if (start) begin
            current_infected <= init_infected;
            days_count <= 4'b0;
          end
        end
        SIMULATING: begin
          if (days_count >= D) begin
            infected_status <= current_infected;
          end else begin
            current_infected <= current_infected | new_infections;
            days_count <= days_count + 1'b1;
          end
        end
        DONE: begin
          // Hold state
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SIMULATING;
        end
      end
      SIMULATING: begin
        if (days_count >= D) begin
          next_state = DONE;
        end
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Done signal
  always @(*) begin
    done = (current_state == DONE);
  end

endmodule