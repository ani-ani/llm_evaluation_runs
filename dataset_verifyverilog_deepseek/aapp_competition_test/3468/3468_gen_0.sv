module app_installer (
  input clk,
  input rst_n,
  input start,
  input [9:0] c,
  input [9:0] d1, s1,
  input [9:0] d2, s2,
  input [9:0] d3, s3,
  input [9:0] d4, s4,
  input [9:0] d5, s5,
  input [9:0] d6, s6,
  input [9:0] d7, s7,
  input [9:0] d8, s8,
  output reg [3:0] max_count,
  output reg [3:0] order [0:7],
  output reg done
);

  reg [9:0] c_reg;
  reg [9:0] d_array [0:7];
  reg [9:0] s_array [0:7];
  reg [9:0] remaining_space;
  reg [3:0] installed_count;
  reg [2:0] sorted_order [0:7];
  reg start_detected;
  reg [3:0] cycle_counter;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      start_detected <= 0;
      cycle_counter <= 0;
      done <= 0;
      max_count <= 0;
      order <= '{0,0,0,0,0,0,0,0};
      remaining_space <= 0;
      installed_count <= 0;
      d_array <= '{0,0,0,0,0,0,0,0};
      s_array <= '{0,0,0,0,0,0,0,0};
      c_reg <= 0;
    end else begin
      if (start && ~start_detected) begin
        start_detected <= 1;
        cycle_counter <= 0;
      end
      if (start_detected) begin
        if (cycle_counter == 11) begin
          start_detected <= 0;
          cycle_counter <= 0;
          done <= 0;
        end else begin
          cycle_counter <= cycle_counter + 1;
        end

        case (cycle_counter)
          0: begin
            d_array[0] <= d1; s_array[0] <= s1;
            d_array[1] <= d2; s_array[1] <= s2;
            d_array[2] <= d3; s_array[2] <= s3;
            d_array[3] <= d4; s_array[3] <= s4;
            d_array[4] <= d5; s_array[4] <= s5;
            d_array[5] <= d6; s_array[5] <= s6;
            d_array[6] <= d7; s_array[6] <= s7;
            d_array[7] <= d8; s_array[7] <= s8;
            c_reg <= c;
            remaining_space <= c;
            installed_count <= 0;
            order <= '{0,0,0,0,0,0,0,0};
          end
          1,2,3,4,5,6,7,8: begin
            if (remaining_space >= (d_array[sorted_order[cycle_counter-1]-1] > s_array[sorted_order[cycle_counter-1]-1] ? d_array[sorted_order[cycle_counter-1]-1] : s_array[sorted_order[cycle_counter-1]-1])) begin
              remaining_space <= remaining_space - s_array[sorted_order[cycle_counter-1]-1];
              order[installed_count] <= sorted_order[cycle_counter-1];
              installed_count <= installed_count + 1;
            end
          end
          9: begin
            max_count <= installed_count;
          end
          10: begin
            done <= 0;
          end
          11: begin
            done <= 1;
          end
        endcase
      end
    end
  end

  always_comb begin
    reg [13:0] key_arr [0:7];
    reg [2:0] idx_arr [0:7];
    if (start_detected && cycle_counter == 0) begin
      for (int i=0; i<8; i++) begin
        key_arr[i] = {s_array[i]-d_array[i], i};
        idx_arr[i] = i;
      end
      for (int i=0; i<8; i++) begin
        reg [13:0] min_key = key_arr[i];
        int min_idx = i;
        for (int j=i+1; j<8; j++) begin
          if (key_arr[j] < min_key) begin
            min_key = key_arr[j];
            min_idx = j;
          end
        end
        // Swap
        key_arr[min_idx] = key_arr[i];
        key_arr[i] = min_key;
        reg [2:0] temp = idx_arr[min_idx];
        idx_arr[min_idx] = idx_arr[i];
        idx_arr[i] = temp;
      end
      for (int i=0; i<8; i++) begin
        sorted_order[i] = idx_arr[i] + 1;
      end
    end else begin
      for (int i=0; i<8; i++) begin
        sorted_order[i] = i+1;
      end
    end
  end

endmodule