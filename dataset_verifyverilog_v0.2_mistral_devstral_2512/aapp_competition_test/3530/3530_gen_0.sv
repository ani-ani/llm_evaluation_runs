module roller_coaster_fun (
  input clk,
  input rst_n,
  input start,
  input [7:0] coaster_a [0:7],
  input [7:0] coaster_b [0:7],
  input [7:0] coaster_t [0:7],
  input [7:0] time_budget,
  output reg [15:0] max_fun,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PREPARE_ITEMS,
    DP_COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [15:0] dp [0:255];
  reg [15:0] item_fun [0:63];
  reg [7:0] item_time [0:63];
  reg [5:0] item_count;
  reg [5:0] current_item;
  reg [7:0] current_time;
  reg [2:0] coaster_idx;
  reg [2:0] ride_count;

  // Initialize DP array
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      dp[i] = 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      item_count <= 0;
      current_item <= 0;
      current_time <= 0;
      coaster_idx <= 0;
      ride_count <= 0;
      done <= 0;
      max_fun <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE_ITEMS;
            item_count <= 0;
            coaster_idx <= 0;
            ride_count <= 0;
          end
        end

        PREPARE_ITEMS: begin
          if (coaster_idx == 8) begin
            state <= DP_COMPUTE;
            current_item <= 0;
            current_time <= 0;
          end else if (ride_count == 8) begin
            coaster_idx <= coaster_idx + 1;
            ride_count <= 0;
          end else begin
            reg [15:0] fun;
            reg [7:0] k_minus_1_sq;
            k_minus_1_sq = (ride_count) * (ride_count);
            fun = coaster_a[coaster_idx] - (k_minus_1_sq * coaster_b[coaster_idx]);
            if (fun > 0) begin
              item_fun[item_count] <= fun;
              item_time[item_count] <= coaster_t[coaster_idx];
              item_count <= item_count + 1;
            end
            ride_count <= ride_count + 1;
          end
        end

        DP_COMPUTE: begin
          if (current_item == item_count) begin
            state <= DONE;
            max_fun <= dp[time_budget];
            done <= 1;
          end else if (current_time == time_budget + 1) begin
            current_item <= current_item + 1;
            current_time <= 0;
          end else begin
            if (current_time >= item_time[current_item]) begin
              reg [15:0] candidate;
              candidate = dp[current_time - item_time[current_item]] + item_fun[current_item];
              if (candidate > dp[current_time]) begin
                dp[current_time] <= candidate;
              end
            end
            current_time <= current_time + 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule