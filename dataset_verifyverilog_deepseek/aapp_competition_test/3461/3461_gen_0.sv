module hearing_scheduler(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_hearings,
  input [15:0] s [0:3],
  input [15:0] a [0:3],
  input [15:0] b [0:3],
  output reg [31:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam CALCULATE = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] cycle_counter;
  reg [15:0] durations [0:3];
  reg [31:0] exp_val [0:3]; // [current][combination]
  reg [5:0] split_idx;
  reg [1:0] curr_hearing;
  wire [31:0] split_step [0:3];
  wire [15:0] step_size [0:3];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case(state)
      IDLE:      next_state = start ? CALCULATE : IDLE;
      CALCULATE: next_state = (cycle_counter == 8'hFF) ? DONE : CALCULATE;
      DONE:      next_state = start ? CALCULATE : DONE;
      default:   next_state = IDLE;
    endcase
  end

  generate
    for (genvar i=0; i<4; i++) begin : calc_split
      assign step_size[i] = (b[i] - a[i]) >> 6;  // Split into 64 intervals
      assign split_step[i] = {step_size[i], 16'h0000}; // Q16.16 format
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 0;
      split_idx <= 0;
      curr_hearing <= 0;
      done <= 0;
      result <= 0;
      for (int i=0; i<4; i++) begin
        durations[i] <= 16'd0;
        exp_val[i] <= 32'd0;
      end
    end
    else begin
      case(state)
        IDLE: begin
          done <= 0;
          cycle_counter <= 0;
          split_idx <= 0;
          curr_hearing <= 0;
          result <= 0;
        end

        CALCULATE: begin
          // Calculate current duration = a + (split_idx * step_size)
          durations[curr_hearing] <= a[curr_hearing] + (split_idx * step_size[curr_hearing]);

          if (curr_hearing == 0) begin
            exp_val[0] <= 32'h10000; // 1.0 in Q16.16
          end else begin
            // Calculate overlap with previous hearing
            if (s[curr_hearing] >= (s[curr_hearing-1] + durations[curr_hearing-1])) begin
              // No overlap
              exp_val[curr_hearing] <= exp_val[curr_hearing-1] + 32'h10000;
            end else begin
              // Overlap - use previous expectation
              exp_val[curr_hearing] <= exp_val[curr_hearing-1];
            end
          end

          // Increment counters
          split_idx <= split_idx + 1;
          if (split_idx == 6'd63) begin
            split_idx <= 0;
            exp_val[curr_hearing] <= (exp_val[curr_hearing] >> 6); // Average over splits
            curr_hearing <= curr_hearing + 1;
          end

          cycle_counter <= cycle_counter + 1;
          if (curr_hearing > num_hearings) begin
            cycle_counter <= 8'hFF;
          end
        end

        DONE: begin
          done <= 1;
          result <= exp_val[num_hearings];
        end
      endcase
    end
  end

endmodule
