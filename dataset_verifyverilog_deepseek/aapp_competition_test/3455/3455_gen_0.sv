module lane_safety_calculator(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [9:0] R,
  input [1:0] car_lane [0:4],
  input [9:0] car_length [0:4],
  input [9:0] car_distance [0:4],
  output reg [31:0] safety_factor,
  output reg impossible,
  output reg done
);

typedef enum logic [1:0] {IDLE, CALC_PATHS, FIND_MAX_MIN, DONE} state_t;

state_t current_state, next_state;

reg signed [31:0] lane_safety [0:3];
reg signed [31:0] path_safeties [0:3];
reg [2:0] num_lanes;
reg [1:0] num_paths;
reg signed [31:0] max_path_safety;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) current_state <= IDLE;
  else current_state <= next_state;
end

always_comb begin
  next_state = current_state;
  case (current_state)
    IDLE: if (start) next_state = CALC_PATHS;
    CALC_PATHS: next_state = FIND_MAX_MIN;
    FIND_MAX_MIN: next_state = DONE;
    DONE: next_state = IDLE;
  endcase
end

always_comb begin
  case (N)
    2'b00: num_lanes = 2;
    2'b01: num_lanes = 3;
    2'b10: num_lanes = 4;
    default: num_lanes = 2;
  endcase
end

always_ff @(posedge clk) begin
  if (current_state == CALC_PATHS) begin
    for (int i=0; i<4; i++) begin
      if (i < num_lanes) begin
        lane_safety[i] = R;
        for (int j=0; j<5; j++) begin
          if (j < M && car_lane[j] == i) begin
            automatic signed [10:0] eff_dist = car_distance[j] - car_length[j];
            if (eff_dist <= R && eff_dist < lane_safety[i]) begin
              lane_safety[i] = eff_dist;
            end
          end
        end
      end
    end
  end
end

always_ff @(posedge clk) begin
  if (current_state == FIND_MAX_MIN) begin
    case (num_lanes)
      2: begin
        path_safeties[0] = (lane_safety[0] < lane_safety[1]) ? lane_safety[0] : lane_safety[1];
        num_paths = 1;
        max_path_safety = path_safeties[0];
      end
      3: begin
        automatic signed [31:0] p0_min = (lane_safety[0] < lane_safety[1]) ? lane_safety[0] : lane_safety[1];
        path_safeties[0] = (p0_min < lane_safety[2]) ? p0_min : lane_safety[2];
        path_safeties[1] = (lane_safety[0] < lane_safety[2]) ? lane_safety[0] : lane_safety[2];
        num_paths = 2;
        max_path_safety = (path_safeties[0] > path_safeties[1]) ? path_safeties[0] : path_safeties[1];
      end
      4: begin
        automatic signed [31:0] p0a = (lane_safety[0] < lane_safety[1]) ? lane_safety[0] : lane_safety[1];
        automatic signed [31:0] p0b = (lane_safety[2] < lane_safety[3]) ? lane_safety[2] : lane_safety[3];
        path_safeties[0] = (p0a < p0b) ? p0a : p0b;
        automatic signed [31:0] p1a = (lane_safety[0] < lane_safety[1]) ? lane_safety[0] : lane_safety[1];
        path_safeties[1] = (p1a < lane_safety[3]) ? p1a : lane_safety[3];
        automatic signed [31:0] p2a = (lane_safety[0] < lane_safety[2]) ? lane_safety[0] : lane_safety[2];
        path_safeties[2] = (p2a < lane_safety[3]) ? p2a : lane_safety[3];
        path_safeties[3] = (lane_safety[0] < lane_safety[3]) ? lane_safety[0] : lane_safety[3];
        num_paths = 4;
        max_path_safety = (path_safeties[0] > path_safeties[1]) ? path_safeties[0] : path_safeties[1];
        if (path_safeties[2] > max_path_safety) max_path_safety = path_safeties[2];
        if (path_safeties[3] > max_path_safety) max_path_safety = path_safeties[3];
      end
      default: begin
        num_paths = 0;
        max_path_safety = 0;
      end
    endcase
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    safety_factor <= 0;
    impossible <= 0;
  end else if (current_state == DONE) begin
    done <= 1;
    if (max_path_safety > 0) begin
      safety_factor <= max_path_safety << 16;
      impossible <= 0;
    end else begin
      safety_factor <= 0;
      impossible <= 1;
    end
  end else done <= 0;
end

endmodule