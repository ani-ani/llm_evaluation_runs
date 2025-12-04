module courier_partition_optimizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] x[0:7],
  input [3:0] y[0:7],
  input [2:0] num_customers,
  output reg [4:0] min_max_time,
  output reg done
);

typedef enum logic [1:0] {IDLE, EVAL_PARTITIONS, DONE} state_t;
state_t state;

reg [7:0] counter;
reg [4:0] min_max_time_reg;
reg [7:0] max_partitions;
wire [7:0] bitmask = counter + 1;

reg [4:0] diameter_A, diameter_B;
reg [4:0] current_min;

always @(*) begin
  reg [3:0] min_xA = 15;
  reg [3:0] max_xA = 0;
  reg [3:0] min_yA = 15;
  reg [3:0] max_yA = 0;
  reg [3:0] min_xB = 15;
  reg [3:0] max_xB = 0;
  reg [3:0] min_yB = 15;
  reg [3:0] max_yB = 0;

  for (int i=0; i<8; i++) begin
    if (i < num_customers) begin
      if (bitmask[i]) begin
        if (x[i] < min_xA) min_xA = x[i];
        if (x[i] > max_xA) max_xA = x[i];
        if (y[i] < min_yA) min_yA = y[i];
        if (y[i] > max_yA) max_yA = y[i];
      end else begin
        if (x[i] < min_xB) min_xB = x[i];
        if (x[i] > max_xB) max_xB = x[i];
        if (y[i] < min_yB) min_yB = y[i];
        if (y[i] > max_yB) max_yB = y[i];
      end
    end
  end

  diameter_A = (max_xA - min_xA) + (max_yA - min_yA);
  diameter_B = (max_xB - min_xB) + (max_yB - min_yB);
  current_min = diameter_A < diameter_B ? diameter_A : diameter_B;
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    min_max_time_reg <= 5'b11111;
    counter <= 8'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) begin
          max_partitions <= (1 << num_customers) - 2;
          counter <= 0;
          min_max_time_reg <= 5'b11111;
          state <= EVAL_PARTITIONS;
        end
      end

      EVAL_PARTITIONS: begin
        if (current_min < min_max_time_reg) 
          min_max_time_reg <= current_min;

        if (counter < max_partitions)
          counter <= counter + 1;
        else
          state <= DONE;
      end

      DONE: begin
        done <= 1;
        state <= IDLE;
      end
    endcase
  end
end

assign min_max_time = min_max_time_reg;

endmodule