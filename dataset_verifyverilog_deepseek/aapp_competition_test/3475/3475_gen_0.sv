module transport_switch_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] t,
  input [2:0] n,
  input [31:0] min_dists [0:3],
  input [31:0] max_angles [0:3],
  input [31:0] dists [0:7],
  input [31:0] angles [0:7],
  output reg [3:0] switch_count,
  output reg done
);

  localparam IDLE = 2'd0;
  localparam COMPUTE = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state;
  reg [2:0] current_i;
  reg [3:0] dp [0:7][0:3];
  reg [3:0] temp_min [0:3];

  integer j, k, k_prev, m;
  reg [31:0] sum_seg;
  reg [31:0] min_angle_seg, max_angle_seg;
  reg [3:0] new_cost;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      switch_count <= 0;
      current_i <= 0;
      state <= IDLE;
      for (int i = 0; i < 8; i++) begin
        for (int kt = 0; kt < 4; kt++) begin
          dp[i][kt] <= 4'b1111;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            for (int kt = 0; kt < 4; kt++) begin
              dp[0][kt] <= 0;
            end
            current_i <= 1;
            done <= 0;
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          if (current_i >= n) begin
            state <= DONE;
          end else begin
            for (k = 0; k < 4; k++) begin
              dp[current_i][k] <= temp_min[k];
            end
            current_i <= current_i + 1;
          end
        end

        DONE: begin
          state <= IDLE;
          done <= 1;
          switch_count <= 4'b1111;
          for (int kt = 0; kt < 4; kt++) begin
            if (dp[n-1][kt] < switch_count) begin
              switch_count <= dp[n-1][kt];
            end
          end
        end
      endcase
    end
  end

  always_comb begin
    for (k = 0; k < 4; k++) begin
      temp_min[k] = 4'b1111;
    end
    if (state == COMPUTE && current_i < n) begin
      for (j = 0; j < current_i; j++) begin
        sum_seg = 0;
        for (m = j; m < current_i; m++) begin
          sum_seg = sum_seg + dists[m];
        end
        min_angle_seg = angles[j];
        max_angle_seg = angles[j];
        for (m = j+1; m < current_i; m++) begin
          if (angles[m] < min_angle_seg) begin
            min_angle_seg = angles[m];
          end
          if (angles[m] > max_angle_seg) begin
            max_angle_seg = angles[m];
          end
        end
        for (k = 0; k < 4; k++) begin
          if (sum_seg >= min_dists[k] && (max_angle_seg - min_angle_seg) <= max_angles[k]) begin
            for (k_prev = 0; k_prev < 4; k_prev++) begin
              if (dp[j][k_prev] != 4'b1111) begin
                new_cost = dp[j][k_prev] + ((k_prev != k) ? 4'd1 : 4'd0);
                if (new_cost < temp_min[k]) begin
                  temp_min[k] = new_cost;
                end
              end
            end
          end
        end
      end
    end
  end

endmodule