module max_bling_calculator (
  input clk,
  input rst_n,
  input start,
  input [2:0] days_remaining,
  input [15:0] initial_bling,
  input [6:0] initial_fruits,
  input [6:0] t0,
  input [6:0] t1,
  input [6:0] t2,
  output reg [15:0] max_bling,
  output reg done
);

  typedef enum reg [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state;

  reg [15:0] current_bling;
  reg [6:0] normal_fruits;
  reg [6:0] exotic_fruits;
  reg [2:0] days_counter;
  reg [6:0] t0_reg, t1_reg, t2_reg;
  reg [6:0] exotic_t0, exotic_t1, exotic_t2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_bling <= 0;
      current_bling <= 0;
      normal_fruits <= 0;
      exotic_fruits <= 0;
      t0_reg <= 0;
      t1_reg <= 0;
      t2_reg <= 0;
      exotic_t0 <= 0;
      exotic_t1 <= 0;
      exotic_t2 <= 0;
      days_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          max_bling <= 0;
          if (start) begin
            current_bling <= initial_bling;
            normal_fruits <= initial_fruits;
            exotic_fruits <= 0;
            t0_reg <= t0;
            t1_reg <= t1;
            t2_reg <= t2;
            exotic_t0 <= 0;
            exotic_t1 <= 0;
            exotic_t2 <= 0;
            days_counter <= days_remaining;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          // Harvest phase
          normal_fruits <= normal_fruits + 3*t0_reg;
          exotic_fruits <= exotic_fruits + 3*exotic_t0;
          
          t0_reg <= t1_reg;
          t1_reg <= t2_reg;
          t2_reg <= 0;
          
          exotic_t0 <= exotic_t1;
          exotic_t1 <= exotic_t2;
          exotic_t2 <= 0;
          
          // Action phase a
          if (current_bling >= 400) begin
            current_bling <= current_bling - 16'd400;
            if (days_counter >= 3) exotic_t2 <= 7'd1;
            else current_bling <= current_bling + 16'd700;
          end
          
          // Action phase b - fruits processing
          if (days_counter >= 3) begin
            t2_reg <= normal_fruits + 3*t0_reg;
            exotic_t2 <= exotic_fruits + 3*exotic_t0 + ((current_bling >= 400) && (days_counter >= 3));
          end else begin
            current_bling <= current_bling + (normal_fruits + 3*t0_reg)*100 + (exotic_fruits + 3*exotic_t0)*700 + ((current_bling >= 400) && (days_counter < 3)) ? 700 : 0;
          end
          
          normal_fruits <= 0;
          exotic_fruits <= 0;
          
          days_counter <= days_counter - 1;
          if (days_counter == 1) state <= DONE;
        end

        DONE: begin
          done <= 1;
          max_bling <= current_bling;
          state <= DONE;
        end
      endcase
    end
  end

endmodule