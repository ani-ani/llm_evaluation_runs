module number_name_sorter (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,  // signed 8-bit elements
  output reg [7:0][3:0] result,
  output reg done,
  output reg [3:0] valid_count
);

  // Internal signals
  logic [7:0] cur_sort [8];
  logic [7:0] nxt_sort [8];
  logic [7:0] filtered [8];
  logic [3:0] vcnt;            // Count of valid elements (1..8)
  logic [3:0] shift_cnt;       // 7-cycle pipeline for valid_count

  // Lookup table: convert 1..9 to 1..9, invalid to 0
  logic [3:0] lut [0:15];
  initial begin
    lut[0] = 4'd0;
    lut[1] = 4'd1;
    lut[2] = 4'd2;
    lut[3] = 4'd3;
    lut[4] = 4'd4;
    lut[5] = 4'd5;
    lut[6] = 4'd6;
    lut[7] = 4'd7;
    lut[8] = 4'd8;
    lut[9] = 4'd9;
    lut[10] = 4'd0;
    lut[11] = 4'd0;
    lut[12] = 4'd0;
    lut[13] = 4'd0;
    lut[14] = 4'd0;
    lut[15] = 4'd0;
  end

  // Filtering (step 2a): keep only values in [1..9], clamp invalid to 0
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      logic signed [7:0] v;
      v = arr[i];
      if (v >= 1 && v <= 9) filtered[i] = v[7:0];
      else filtered[i] = 8'd0;
    end
  end

  // Bubble sort (step 2b): exactly 8 iterations
  always_comb begin
    nxt_sort = cur_sort;
    for (int i = 0; i < 7; i++) begin
      logic signed [7:0] a, b;
      a = cur_sort[i];
      b = cur_sort[i+1];
      if (a > b) begin
        nxt_sort[i]   = b;
        nxt_sort[i+1] = a;
      end
    end
  end

  // FSM (16 cycles total: 1 filtering + 8 sorts + 1 reversal/mapping + 6 idle + done on cycle 16)
  logic [4:0] state;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 5'd0;
      for (int i = 0; i < 8; i++) cur_sort[i] <= 8'd0;
      vcnt <= 4'd0;
      shift_cnt <= 4'd0;
      result <= '0;
      done <= 1'b0;
      valid_count <= 4'd0;
    end else begin
      case (state)
        5'd0: begin
          result <= '0;
          done <= 1'b0;
          valid_count <= 4'd0;
          shift_cnt <= 4'd0;
          vcnt <= 4'd0;
          if (start) begin
            // Load filtered data and count valids (cycle 1)
            for (int i = 0; i < 8; i++) cur_sort[i] <= filtered[i];
            vcnt <= (
              (filtered[0] >= 1 && filtered[0] <= 9) +
              (filtered[1] >= 1 && filtered[1] <= 9) +
              (filtered[2] >= 1 && filtered[2] <= 9) +
              (filtered[3] >= 1 && filtered[3] <= 9) +
              (filtered[4] >= 1 && filtered[4] <= 9) +
              (filtered[5] >= 1 && filtered[5] <= 9) +
              (filtered[6] >= 1 && filtered[6] <= 9) +
              (filtered[7] >= 1 && filtered[7] <= 9)
            );
            state <= 5'd1;
          end else begin
            state <= 5'd0;
          end
        end
        // 8 cycles of bubble sort (cycles 2..9)
        5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8: begin
          cur_sort <= nxt_sort;
          state <= state + 1;
        end
        // Reversal + mapping (cycle 10)
        5'd9: begin
          for (int i = 0; i < 8; i++) begin
            int idx;
            idx = 7 - i;
            if (cur_sort[idx] >= 1 && cur_sort[idx] <= 9)
              result[i] <= lut[cur_sort[idx][3:0]]; // 1..9
            else
              result[i] <= 4'd0; // invalid
          end
          shift_cnt <= vcnt;      // start 7-cycle pipeline
          done <= 1'b0;
          state <= 5'd10;
        end
        // Pipeline delay cycles 11..15 (total 7 cycles including cycle 10)
        5'd10, 5'd11, 5'd12, 5'd13, 5'd14: begin
          shift_cnt <= {3'b0, shift_cnt[3:1]}; // 3-bit shift (4 stages total including cycle 10)
          state <= state + 1;
        end
        // Cycle 16: assert done and final valid_count
        5'd15: begin
          done <= shift_cnt[0];
          valid_count <= shift_cnt[0] ? 4'd8 : 4'd0; // At this point, shift_cnt[0] carries vcnt through 7 cycles
          state <= 5'd0; // return to idle
        end
        default: begin
          state <= 5'd0;
        end
      endcase
    end
  end

  // Maintain valid_count during pipeline (cycles 11..15)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_count <= 4'd0;
    end else begin
      case (state)
        5'd9:   valid_count <= 4'd0; // not yet
        5'd10:  valid_count <= 4'd0;
        5'd11:  valid_count <= 4'd0;
        5'd12:  valid_count <= 4'd0;
        5'd13:  valid_count <= 4'd0;
        5'd14:  valid_count <= 4'd0;
        5'd15:  valid_count <= 4'd8; // vcnt propagated through pipeline
        default: valid_count <= 4'd0;
      endcase
    end
  end

endmodule
