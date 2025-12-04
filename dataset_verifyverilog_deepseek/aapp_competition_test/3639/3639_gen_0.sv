module optimal_cycling(
  input clk,
  input rst_n,
  input start,
  input [3:0] T,
  input [31:0] c_fp,
  input [31:0] d_fp,
  input [7:0] rain [0:15],
  output reg [31:0] min_wetness_fp,
  output reg done
);

  typedef enum logic [2:0] { IDLE, INIT, COMPUTE_PH1, COMPUTE_PH2, DONE } state_t;

  localparam [31:0] speed_rom [0:7] = '{
    32'h00050000, 32'h000A0000, 32'h000F0000, 32'h00140000,
    32'h00190000, 32'h001E0000, 32'h00230000, 32'h00280000 };

  logic [15:0] prefix_sum [0:15];
  state_t current_state, next_state;
  reg [3:0] leave_time_ctr;
  reg [2:0] speed_ctr;
  reg [31:0] reg_current_speed;
  reg [31:0] reg_travel_time;
  reg [15:0] reg_duration_int;
  reg [3:0] reg_end_time;
  reg [15:0] reg_rain_sum;
  reg [31:0] reg_current_wetness;

  generate
    for (genvar i = 0; i < 16; i++) begin
      if (i == 0) assign prefix_sum[i] = rain[i];
      else assign prefix_sum[i] = prefix_sum[i-1] + rain[i];
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      leave_time_ctr <= 4'b0;
      speed_ctr <= 3'b0;
      min_wetness_fp <= {32{1'b1}};
      done <= 1'b0;
      reg_current_speed <= 32'b0;
      reg_travel_time <= 32'b0;
      reg_duration_int <= 16'b0;
    end
    else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) current_state <= INIT;
        end

        INIT: begin
          leave_time_ctr <= 4'b0;
          speed_ctr <= 3'b0;
          min_wetness_fp <= {32{1'b1}};
          current_state <= COMPUTE_PH1;
        end

        COMPUTE_PH1: begin
          if (leave_time_ctr >= T) current_state <= DONE;
          else begin
            reg_current_speed <= speed_rom[speed_ctr];
            if (speed_rom[speed_ctr] != 0) begin
              reg_travel_time <= (d_fp << 16) / speed_rom[speed_ctr];
              reg_duration_int <= ((reg_travel_time * 32'h3C00000) >> 32) + 
                                   (((reg_travel_time * 32'h3C00000) & 32'hFFFF_FFFF) != 0);
            end
            current_state <= COMPUTE_PH2;
          end
        end

        COMPUTE_PH2: begin
          if (leave_time_ctr < T) begin
            reg_end_time = leave_time_ctr + reg_duration_int - 1;
            if (reg_end_time > T - 1) reg_end_time = T - 1;
            if (leave_time_ctr == 0) reg_rain_sum = prefix_sum[reg_end_time];
            else reg_rain_sum = prefix_sum[reg_end_time] - prefix_sum[leave_time_ctr-1];

            begin
              logic [127:0] sweat_temp = c_fp * reg_current_speed * reg_current_speed * reg_travel_time;
              reg_current_wetness = sweat_temp[79:48] + (reg_rain_sum << 16);
              if (reg_current_wetness < min_wetness_fp) min_wetness_fp <= reg_current_wetness;
            end

            if (speed_ctr == 3'd7) begin
              speed_ctr <= 3'b0;
              leave_time_ctr <= leave_time_ctr + 1;
            end
            else speed_ctr <= speed_ctr + 1;
          end
          current_state <= COMPUTE_PH1;
        end

        DONE: begin
          done <= 1'b1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule