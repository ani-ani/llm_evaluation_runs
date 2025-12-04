module plant_replanner(
  input clk,
  input rst_n,
  input start,
  input [1:0] species_data [0:15],
  output reg [4:0] replant_count,
  output reg done
);

  reg processing;
  reg [3:0] cycle_count;
  reg [4:0] dp [0:15];
  reg [4:0] max_length;

  integer j;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      cycle_count <= 4'd0;
      replant_count <= 5'd0;
      done <= 1'b0;
      for (int i = 0; i < 16; i++) begin
        dp[i] <= 5'd0;
      end
      max_length <= 5'd0;
    end else begin
      done <= 1'b0;
      if (processing) begin
        if (cycle_count < 4'd15) begin
          cycle_count <= cycle_count + 1'b1;
        end

        reg [4:0] current_dp = 5'd1;
        for (j = 0; j < cycle_count; j++) begin
          if (species_data[j] <= species_data[cycle_count]) begin
            if (dp[j] + 1 > current_dp) begin
              current_dp = dp[j] + 1;
            end
          end
        end
        dp[cycle_count] <= current_dp;
        if (current_dp > max_length) begin
          max_length <= current_dp;
        end

        if (cycle_count == 4'd15) begin
          processing <= 1'b0;
          replant_count <= 16 - max_length;
          done <= 1'b1;
        end
      end else if (start) begin
        processing <= 1'b1;
        cycle_count <= 4'd0;
        max_length <= 5'd0;
      end
    end
  end

endmodule