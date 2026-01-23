module sort_sublists (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_sublists,
  input [2:0] num_strings_0,
  input [2:0] num_strings_1,
  input [2:0] num_strings_2,
  input [63:0] sublist_0_str_0, input [63:0] sublist_0_str_1, input [63:0] sublist_0_str_2, input [63:0] sublist_0_str_3, input [63:0] sublist_0_str_4, input [63:0] sublist_0_str_5, input [63:0] sublist_0_str_6, input [63:0] sublist_0_str_7,
  input [63:0] sublist_1_str_0, input [63:0] sublist_1_str_1, input [63:0] sublist_1_str_2, input [63:0] sublist_1_str_3, input [63:0] sublist_1_str_4, input [63:0] sublist_1_str_5, input [63:0] sublist_1_str_6, input [63:0] sublist_1_str_7,
  input [63:0] sublist_2_str_0, input [63:0] sublist_2_str_1, input [63:0] sublist_2_str_2, input [63:0] sublist_2_str_3, input [63:0] sublist_2_str_4, input [63:0] sublist_2_str_5, input [63:0] sublist_2_str_6, input [63:0] sublist_2_str_7,
  output reg [63:0] result_str_0,
  output reg [2:0] current_sublist,
  output reg result_valid,
  output reg done
);

  reg [63:0] buffer [8];
  reg [2:0] captured_num_sublists;
  reg [2:0] captured_num_strings [3];
  reg [63:0] captured_sublist_strs [2][8];

  reg [3:0] state;
  reg [2:0] processing_phase;
  reg [2:0] current_sublist_idx;
  reg [2:0] sort_pass_cnt;
  reg [2:0] sort_comp_cnt;
  reg [2:0] output_cnt;
  reg start_prev;

  always @(posedge clk) begin
    if (!rst_n) begin
      captured_num_sublists <= 3'd0;
      captured_num_strings <= {3'd0, 3'd0, 3'd0};
      captured_sublist_strs[0][0] <= 64'd0;
      captured_sublist_strs[0][1] <= 64'd0;
      captured_sublist_strs[0][2] <= 64'd0;
      captured_sublist_strs[0][3] <= 64'd0;
      captured_sublist_strs[0][4] <= 64'd0;
      captured_sublist_strs[0][5] <= 64'd0;
      captured_sublist_strs[0][6] <= 64'd0;
      captured_sublist_strs[0][7] <= 64'd0;
      captured_sublist_strs[1][0] <= 64'd0;
      captured_sublist_strs[1][1] <= 64'd0;
      captured_sublist_strs[1][2] <= 64'd0;
      captured_sublist_strs[1][3] <= 64'd0;
      captured_sublist_strs[1][4] <= 64'd0;
      captured_sublist_strs[1][5] <= 64'd0;
      captured_sublist_strs[1][6] <= 64'd0;
      captured_sublist_strs[1][7] <= 64'd0;
      captured_sublist_strs[2][0] <= 64'd0;
      captured_sublist_strs[2][1] <= 64'd0;
      captured_sublist_strs[2][2] <= 64'd0;
      captured_sublist_strs[2][3] <= 64'd0;
      captured_sublist_strs[2][4] <= 64'd0;
      captured_sublist_strs[2][5] <= 64'd0;
      captured_sublist_strs[2][6] <= 64'd0;
      captured_sublist_strs[2][7] <= 64'd0;
      buffer <= {8{64'd0}};
      state <= 4'd0;
      processing_phase <= 3'd0;
      current_sublist_idx <= 3'd0;
      sort_pass_cnt <= 3'd0;
      sort_comp_cnt <= 3'd0;
      output_cnt <= 3'd0;
      start_prev <= 1'b0;
      done <= 1'b0;
    end else begin
      start_prev <= start;
      if (start && !start_prev) begin
        captured_num_sublists <= num_sublists;
        captured_num_strings[0] <= num_strings_0;
        captured_num_strings[1] <= num_strings_1;
        captured_num_strings[2] <= num_strings_2;
        captured_sublist_strs[0][0] <= sublist_0_str_0;
        captured_sublist_strs[0][1] <= sublist_0_str_1;
        captured_sublist_strs[0][2] <= sublist_0_str_2;
        captured_sublist_strs[0][3] <= sublist_0_str_3;
        captured_sublist_strs[0][4] <= sublist_0_str_4;
        captured_sublist_strs[0][5] <= sublist_0_str_5;
        captured_sublist_strs[0][6] <= sublist_0_str_6;
        captured_sublist_strs[0][7] <= sublist_0_str_7;
        captured_sublist_strs[1][0] <= sublist_1_str_0;
        captured_sublist_strs[1][1] <= sublist_1_str_1;
        captured_sublist_strs[1][2] <= sublist_1_str_2;
        captured_sublist_strs[1][3] <= sublist_1_str_3;
        captured_sublist_strs[1][4] <= sublist_1_str_4;
        captured_sublist_strs[1][5] <= sublist_1_str_5;
        captured_sublist_strs[1][6] <= sublist_1_str_6;
        captured_sublist_strs[1][7] <= sublist_1_str_7;
        captured_sublist_strs[2][0] <= sublist_2_str_0;
        captured_sublist_strs[2][1] <= sublist_2_str_1;
        captured_sublist_strs[2][2] <= sublist_2_str_2;
        captured_sublist_strs[2][3] <= sublist_2_str_3;
        captured_sublist_strs[2][4] <= sublist_2_str_4;
        captured_sublist_strs[2][5] <= sublist_2_str_5;
        captured_sublist_strs[2][6] <= sublist_2_str_6;
        captured_sublist_strs[2][7] <= sublist_2_str_7;
      end

      if (state == 4'd0) begin
        if (start && !start_prev) begin
          state <= 4'd1;
          current_sublist_idx <= 3'd0;
          sort_pass_cnt <= 3'd0;
          sort_comp_cnt <= 3'd0;
          output_cnt <= 3'd0;
          processing_phase <= 3'd0;
        end
      end else if (state == 4'd1) begin
        if (processing_phase == 3'd0) begin
          if (current_sublist_idx == 3'd0) begin
            if (0 < captured_num_strings[0]) buffer[0] <= captured_sublist_strs[0][0];
            else buffer[0] <= 64'h2020202020202020;
            if (1 < captured_num_strings[0]) buffer[1] <= captured_sublist_strs[0][1];
            else buffer[1] <= 64'h2020202020202020;
            if (2 < captured_num_strings[0]) buffer[2] <= captured_sublist_strs[0][2];
            else buffer[2] <= 64'h2020202020202020;
            if (3 < captured_num_strings[0]) buffer[3] <= captured_sublist_strs[0][3];
            else buffer[3] <= 64'h2020202020202020;
            if (4 < captured_num_strings[0]) buffer[4] <= captured_sublist_strs[0][4];
            else buffer[4] <= 64'h2020202020202020;
            if (5 < captured_num_strings[0]) buffer[5] <= captured_sublist_strs[0][5];
            else buffer[5] <= 64'h2020202020202020;
            if (6 < captured_num_strings[0]) buffer[6] <= captured_sublist_strs[0][6];
            else buffer[6] <= 64'h2020202020202020;
            if (7 < captured_num_strings[0]) buffer[7] <= captured_sublist_strs[0][7];
            else buffer[7] <= 64'h2020202020202020;
          end
          if (current_sublist_idx == 3'd1) begin
            if (0 < captured_num_strings[1]) buffer[0] <= captured_sublist_strs[1][0];
            else buffer[0] <= 64'h2020202020202020;
            if (1 < captured_num_strings[1]) buffer[1] <= captured_sublist_strs[1][1];
            else buffer[1] <= 64'h2020202020202020;
            if (2 < captured_num_strings[1]) buffer[2] <= captured_sublist_strs[1][2];
            else buffer[2] <= 64'h2020202020202020;
            if (3 < captured_num_strings[1]) buffer[3] <= captured_sublist_strs[1][3];
            else buffer[3] <= 64'h2020202020202020;
            if (4 < captured_num_strings[1]) buffer[4] <= captured_sublist_strs[1][4];
            else buffer[4] <= 64'h2020202020202020;
            if (5 < captured_num_strings[1]) buffer[5] <= captured_sublist_strs[1][5];
            else buffer[5] <= 64'h2020202020202020;
            if (6 < captured_num_strings[1]) buffer[6] <= captured_sublist_strs[1][6];
            else buffer[6] <= 64'h2020202020202020;
            if (7 < captured_num_strings[1]) buffer[7] <= captured_sublist_strs[1][7];
            else buffer[7] <= 64'h2020202020202020;
          end
          if (current_sublist_idx == 3'd2) begin
            if (0 < captured_num_strings[2]) buffer[0] <= captured_sublist_strs[2][0];
            else buffer[0] <= 64'h2020202020202020;
            if (1 < captured_num_strings[2]) buffer[1] <= captured_sublist_strs[2][1];
            else buffer[1] <= 64'h2020202020202020;
            if (2 < captured_num_strings[2]) buffer[2] <= captured_sublist_strs[2][2];
            else buffer[2] <= 64'h2020202020202020;
            if (3 < captured_num_strings[2]) buffer[3] <= captured_sublist_strs[2][3];
            else buffer[3] <= 64'h2020202020202020;
            if (4 < captured_num_strings[2]) buffer[4] <= captured_sublist_strs[2][4];
            else buffer[4] <= 64'h2020202020202020;
            if (5 < captured_num_strings[2]) buffer[5] <= captured_sublist_strs[2][5];
            else buffer[5] <= 64'h2020202020202020;
            if (6 < captured_num_strings[2]) buffer[6] <= captured_sublist_strs[2][6];
            else buffer[6] <= 64'h2020202020202020;
            if (7 < captured_num_strings[2]) buffer[7] <= captured_sublist_strs[2][7];
            else buffer[7] <= 64'h2020202020202020;
          end
          processing_phase <= 3'd1;
        end else if (processing_phase == 3'd1) begin
          if (sort_pass_cnt < 3'd8) begin
            if (sort_comp_cnt < 3'd7) begin
              if (buffer[sort_comp_cnt][63:56] > buffer[sort_comp_cnt+1][63:56]) begin
                buffer[sort_comp_cnt] <= buffer[sort_comp_cnt+1];
                buffer[sort_comp_cnt+1] <= buffer[sort_comp_cnt];
              end
              sort_comp_cnt <= sort_comp_cnt + 1;
            end else begin
              sort_pass_cnt <= sort_pass_cnt + 1;
              sort_comp_cnt <= 3'd0;
            end
          end else begin
            processing_phase <= 3'd2;
          end
        end else if (processing_phase == 3'd2) begin
          if (output_cnt < 3'd8) begin
            result_str_0 <= buffer[output_cnt];
            result_valid <= 1'b1;
            current_sublist <= current_sublist_idx;
            output_cnt <= output_cnt + 1;
          end else begin
            processing_phase <= 3'd3;
          end
        end else if (processing_phase == 3'd3) begin
          if (current_sublist_idx < captured_num_sublists) begin
            current_sublist_idx <= current_sublist_idx + 1;
            processing_phase <= 3'd0;
          end else begin
            state <= 4'd2;
          end
        end
      end
    end
  end

  assign done = (state == 4'd2) || ((processing_phase == 3'd3) && (current_sublist_idx >= captured_num_sublists));
  assign result_valid = (processing_phase == 3'd2) && (output_cnt < 3'd8);
  assign current_sublist = (processing_phase == 3'd2) ? current_sublist_idx : 3'd0;

endmodule
