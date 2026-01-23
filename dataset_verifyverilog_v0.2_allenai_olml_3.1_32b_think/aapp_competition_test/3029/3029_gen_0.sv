module tree_lis_solver (
   input clk,
   input rst_n,
   input start,
   input valid_in,
   input [15:0] node_label,
   input [2:0] node_parent,
   output reg [3:0] max_length,
   output reg [15:0] path_count,
   output reg done
);

localparam MOD = 11092019;

reg [15:0] label_reg [0:7];
reg [2:0] parent_index [0:7];
reg [3:0] len_reg [0:7];
reg [15:0] cnt_reg [0:7];
reg [3:0] max_length;
reg [15:0] path_count;
reg done;
reg [2:0] node_idx;

always @(posedge clk) begin
   if (!rst_n) begin
      node_idx <= 0;
      max_length <= 0;
      path_count <= 0;
      done <= 0;
      for (int i=0; i<8; i=i+1) begin
         label_reg[i] <= 0;
         parent_index[i] <= 0;
         len_reg[i] <= 0;
         cnt_reg[i] <= 0;
      end
   end else begin
      if (start && valid_in) begin
         int current_idx = node_idx;
         if (current_idx < 8) begin
            label_reg[current_idx] <= node_label;
            parent_index[current_idx] <= node_parent;

            int temp_len = 1;
            int temp_cnt = 1;
            int ancestor;

            // Level 1: parent
            ancestor = node_parent;
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 2: grandparent
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 3
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 4
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 5
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 6
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            // Level 7
            ancestor = parent_index[ancestor];
            if (ancestor != 0) begin
               if (label_reg[ancestor] <= node_label) begin
                  if (len_reg[ancestor] + 1 > temp_len) begin
                     temp_len = len_reg[ancestor] + 1;
                     temp_cnt = cnt_reg[ancestor];
                  end else if (len_reg[ancestor] + 1 == temp_len) begin
                     temp_cnt = temp_cnt + cnt_reg[ancestor];
                  end
               end
            end

            len_reg[current_idx] <= temp_len;
            cnt_reg[current_idx] <= temp_cnt;

            if (temp_len > max_length) begin
               max_length <= temp_len;
               path_count <= temp_cnt;
            end else if (temp_len == max_length) begin
               path_count <= (path_count + temp_cnt) % MOD;
            end

            if (current_idx == 7) begin
               done <= 1;
            end
            node_idx <= current_idx + 1;
         end else begin
            done <= 1;
         end
      end
   end
end