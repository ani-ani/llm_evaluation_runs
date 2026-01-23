module interstellar_optimizer (
input clk,
input rst_n,
input start,
input [2:0] star_idx,
input config_valid,
input [15:0] config_T,
input [15:0] config_s,
input [7:0] config_a,
output reg [23:0] result,
output reg done
);

reg [23:0] max_distance;
reg [7:0] event_angle [23:0];
reg [16:0] event_delta [23:0];
reg [2:0] expected_star_idx;
reg [2:0] star_count;
reg [3:0] state;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= 0;
    expected_star_idx <= 0;
    star_count <= 0;
    max_distance <= 0;
  end else begin
    if (state == 0) begin // IDLE
      if (start) state <= 1; // go to CONFIG
    end else if (state == 1) begin // CONFIG
      if (star_idx == expected_star_idx && config_valid) begin
        star_count <= star_count + 1;
        expected_star_idx <= star_count;
        if (star_count == 8) begin
          state <= 2; // CALCULATE
        end
      end
    end else if (state == 2) begin // CALCULATE
      // Dummy: after one cycle, move to DONE
      if (star_count ==8) state <=3;
    end
    // DONE state does nothing
  end
end

always_comb begin
  done = (state == 3);
  result = max_distance;
  // Other combinational logic
end

endmodule