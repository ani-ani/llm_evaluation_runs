module tv_coverage(
  input clk,
  input rst_n,
  input start,
  input [4:0] city_length,
  input [0:7] has_transmitter,
  input [4:0] building_pos [0:7],
  input [4:0] building_height [0:7],
  output reg [15:0] coverage_length,
  output reg done
);

  localparam Q12_4 = 16;
  localparam MAX_BUILDINGS = 8;

  // Inputs registered in Q12.4 format
  reg [Q12_4-1:0] city_length_q;
  reg [Q12_4-1:0] building_pos_q [0:MAX_BUILDINGS-1];
  reg [Q12_4-1:0] building_height_q [0:MAX_BUILDINGS-1];
  reg [0:MAX_BUILDINGS-1] has_transmitter_q;

  typedef struct {
    logic valid;
    logic [Q12_4-1:0] start;
    logic [Q12_4-1:0] end;
  } segment_t;

  segment_t [MAX_BUILDINGS-1:0] segments;
  segment_t [MAX_BUILDINGS-1:0] sorted_segments;
  segment_t [MAX_BUILDINGS-1:0] merged_segments;

  reg [15:0] cycle_counter;
  reg processing;

  // Fixed-point division (inline placeholder)
  function logic [Q12_4-1:0] fp_divide(input [Q12_4-1:0] num, input [Q12_4-1:0] den);
    if (den == 0) return 1; // Avoid divide by zero
    fp_divide = (num << 4) / den; // Approximation
  endfunction

  // Compute left coverage for transmitter j
  function logic [Q12_4-1:0] calc_left_coverage(input [Q12_4-1:0] tx_p, input [Q12_4-1:0] tx_h, input integer tx_idx);
    logic [Q12_4-1:0] max_left;
    logic [Q12_4-1:0] denom, numerator, x_pos;
    max_left = 0;
    for (int i = 0; i < MAX_BUILDINGS; i++) begin
      if ((building_pos_q[i] < tx_p) && (i != tx_idx)) begin
        if (building_height_q[i] >= tx_h) begin
          max_left = building_pos_q[i]; // Completely blocked
        end else begin
          // Calculate intercept: x = bp - (bh * (tx_p - bp)) / (tx_h - bh)
          numerator = (building_pos_q[i]*(tx_h - building_height_q[i])) - (tx_p*building_height_q[i]);
          denom = tx_h - building_height_q[i];
          if (denom != 0) x_pos = fp_divide(numerator, denom);
          if (x_pos > max_left) max_left = x_pos;
        end
      end
    end
    calc_left_coverage = max_left;
  endfunction

  // Compute right coverage for transmitter j
  function logic [Q12_4-1:0] calc_right_coverage(input [Q12_4-1:0] tx_p, input [Q12_4-1:0] tx_h, input integer tx_idx);
    logic [Q12_4-1:0] min_right;
    logic [Q12_4-1:0] denom, numerator, x_pos;
    min_right = city_length_q;
    for (int i = 0; i < MAX_BUILDINGS; i++) begin
      if ((building_pos_q[i] > tx_p) && (i != tx_idx)) begin
        if (building_height_q[i] >= tx_h) begin
          min_right = building_pos_q[i]; // Completely blocked
        end else begin
          // Calculate intercept: x = bp + (bh * (bp - tx_p)) / (tx_h - bh)
          numerator = (building_pos_q[i]*(tx_h - building_height_q[i])) - (tx_p*building_height_q[i]);
          denom = tx_h - building_height_q[i];
          if (denom != 0) x_pos = fp_divide(numerator, denom);
          if (x_pos < min_right) min_right = x_pos;
        end
      end
    end
    calc_right_coverage = min_right;
  endfunction

  // Bubble Sort segments by start
  function void sort_segments(input segment_t [MAX_BUILDINGS-1:0] in_arr, output segment_t [MAX_BUILDINGS-1:0] out_arr);
    out_arr = in_arr;
    for (int i = 0; i < MAX_BUILDINGS-1; i++) begin
      for (int j = 0; j < MAX_BUILDINGS-i-1; j++) begin
        if (out_arr[j].valid && out_arr[j+1].valid && (out_arr[j].start > out_arr[j+1].start)) begin
          segment_t temp = out_arr[j];
          out_arr[j] = out_arr[j+1];
          out_arr[j+1] = temp;
        end
      end
    end
  endfunction

  // Merge sorted segments
  function void merge_segments(input segment_t [MAX_BUILDINGS-1:0] in_arr, output segment_t [MAX_BUILDINGS-1:0] out_arr);
    int merged_count = 0;
    if (in_arr[0].valid) begin
      out_arr[0] = in_arr[0];
      merged_count = 0;
      for (int i = 1; i < MAX_BUILDINGS; i++) begin
        if (!in_arr[i].valid) break;
        if (in_arr[i].start <= out_arr[merged_count].end) begin
          if (in_arr[i].end > out_arr[merged_count].end)
            out_arr[merged_count].end = in_arr[i].end;
        end else begin
          merged_count++;
          out_arr[merged_count] = in_arr[i];
        end
      end
    end
  endfunction

  // Sum merged segment lengths
  function logic [Q12_4-1:0] sum_segments(input segment_t [MAX_BUILDINGS-1:0] segs);
    sum_segments = 0;
    for (int i = 0; i < MAX_BUILDINGS; i++) begin
      if (segs[i].valid) begin
        if (segs[i].end > segs[i].start)
          sum_segments += segs[i].end - segs[i].start;
      end
    end
  endfunction

  // Main FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      cycle_counter <= 0;
      done <= 0;
      processing <= 0;
      coverage_length <= 0;
      for (int i = 0; i < MAX_BUILDINGS; i++) begin
        segments[i] <= '{valid:0, start:0, end:0};
        sorted_segments[i] <= '{valid:0, start:0, end:0};
        merged_segments[i] <= '{valid:0, start:0, end:0};
      end
    end else begin
      done <= 0;
      if (start || processing) begin
        cycle_counter <= cycle_counter + 1;
        processing <= 1;

        case (cycle_counter)
          0: begin
            // Register inputs
            city_length_q <= city_length << 4;
            for (int i = 0; i < MAX_BUILDINGS; i++) begin
              building_pos_q[i] <= building_pos[i] << 4;
              building_height_q[i] <= building_height[i] << 4;
              has_transmitter_q[i] <= has_transmitter[i];
              segments[i] <= '{valid:0, start:0, end:0};
            end
          end
          1: begin
            // Calculate coverage for each transmitter
            for (int i = 0; i < MAX_BUILDINGS; i++) begin
              if (has_transmitter_q[i]) begin
                segments[i].valid <= 1;
                segments[i].start <= calc_left_coverage(building_pos_q[i], building_height_q[i], i);
                segments[i].end <= calc_right_coverage(building_pos_q[i], building_height_q[i], i);
              end
            end
          end
          2,3,4,5,6,7,8: begin
            // Pipelined delay for calc functions
            // (If combinational, remove cycles; otherwise adjust)
            // ...
          end
          9: begin
            // Sort segments
            sort_segments(segments, sorted_segments);
          end
          10: begin
            // Merge segments
            merge_segments(sorted_segments, merged_segments);
          end
          11: begin
            // Sum segment lengths
            coverage_length <= sum_segments(merged_segments);
          end
          12,13,14,15: ; // Pipeline stages delay (adjust as needed)
          16: begin
            done <= 1;
            cycle_counter <= 0;
            processing <= 0;
          end
        endcase

        if (cycle_counter == 16) cycle_counter <= 0;
      end
    end
  end
endmodule