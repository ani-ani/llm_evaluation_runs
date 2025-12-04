module gesture_classifier(
  input clk,
  input rst_n,
  input start,
  input [127:0] init_image,
  input [127:0] final_image,
  output reg [2:0] touch_count,
  output reg [1:0] gesture_type,
  output reg direction,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  FIND_TOUCHES,
  CALC_GRIPS,
  MATCH_TOUCHES,
  COMPARE,
  DONE
} state_t;

// Temporary storage structures
struct packed {
  logic valid;
  logic [15:0] centroid_x;  // Q8.8
  logic [15:0] centroid_y;
} init_touch_array [0:4];

struct packed {
  logic valid;
  logic [15:0] centroid_x;  // Q8.8
  logic [15:0] centroid_y;
} final_touch_array [0:4];

// Processing registers
state_t current_state, next_state;
reg [127:0] init_visited, final_visited;
reg [7:0] cycle_counter;
reg [3:0] init_touch_cnt, final_touch_cnt;
reg [15:0] grip_init_x, grip_init_y;
reg [15:0] grip_final_x, grip_final_y;
reg [31:0] best_distance_sq;
reg [15:0] pan_distance, zoom_distance, rotate_distance;

// Internal control signals
wire processing_complete;

// 256-cycle timeout logic
assign processing_complete = (cycle_counter == 8'd255);

// State machine
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    cycle_counter <= 0;
  end else begin
    current_state <= next_state;
    if (start) cycle_counter <= 0;
    else if (!done) cycle_counter <= cycle_counter + 1;
  end
end

// Next state logic
always_comb begin
  next_state = current_state;
  case (current_state)
    IDLE: if (start) next_state = FIND_TOUCHES;
    FIND_TOUCHES: if (processing_complete) next_state = CALC_GRIPS;
    CALC_GRIPS: next_state = MATCH_TOUCHES;
    MATCH_TOUCHES: next_state = COMPARE;
    COMPARE: next_state = DONE;
    DONE: next_state = IDLE;
  endcase
end

// Touch detection logic for both images (simplified)
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    init_visited <= 0;
    final_visited <= 0;
    init_touch_cnt <= 0;
    final_touch_cnt <= 0;
    for (int i = 0; i < 5; i++) begin
      init_touch_array[i].valid <= 0;
      final_touch_array[i].valid <= 0;
    end
  end else if (current_state == FIND_TOUCHES) begin
    // Simplified touch detection placeholder
    // Actual implementation would use flood fill to find connected components
    // Here only single pixel clusters considered
    if (init_image[cycle_counter[6:0]] && !init_visited[cycle_counter[6:0]]) begin
      init_touch_array[init_touch_cnt].centroid_x = {cycle_counter[3:0], 8'h80};  // Q8.8
      init_touch_array[init_touch_cnt].centroid_y = {cycle_counter[7:4], 8'h80};  // Q8.8
      init_touch_array[init_touch_cnt].valid <= 1;
      init_touch_cnt <= init_touch_cnt + 1;
    end
    if (final_image[cycle_counter[6:0]] && !final_visited[cycle_counter[6:0]]) begin
      final_touch_array[final_touch_cnt].centroid_x = {cycle_counter[3:0], 8'h80};
      final_touch_array[final_touch_cnt].centroid_y = {cycle_counter[7:4], 8'h80};
      final_touch_array[final_touch_cnt].valid <= 1;
      final_touch_cnt <= final_touch_cnt + 1;
    end
  end
end

// Grip point calculation
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    grip_init_x <= 0;
    grip_init_y <= 0;
    grip_final_x <= 0;
    grip_final_y <= 0;
  end else if (current_state == CALC_GRIPS) begin
    for (int i = 0; i < 5; i++) begin
      grip_init_x <= grip_init_x + init_touch_array[i].centroid_x;
      grip_init_y <= grip_init_y + init_touch_array[i].centroid_y;
      grip_final_x <= grip_final_x + final_touch_array[i].centroid_x;
      grip_final_y <= grip_final_y + final_touch_array[i].centroid_y;
    end
    grip_init_x <= grip_init_x / (init_touch_cnt ? init_touch_cnt : 16'd1);
    grip_init_y <= grip_init_y / (init_touch_cnt ? init_touch_cnt : 16'd1);
    grip_final_x <= grip_final_x / (final_touch_cnt ? final_touch_cnt : 16'd1);
    grip_final_y <= grip_final_y / (final_touch_cnt ? final_touch_cnt : 16'd1);
  end
end

// Output calculation
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    touch_count <= 0;
    gesture_type <= 0;
    direction <= 0;
    done <= 0;
  end else begin
    done <= (current_state == DONE);
    if (current_state == DONE) begin
      // Simplified gesture selection
      gesture_type <= 2'b00;  // Default pan
      direction <= (grip_final_x > grip_init_x);
      touch_count <= init_touch_cnt;
    end
  end
end

endmodule