module cycle_partition(input clk, input rst_n, input start, input [15:0] adj_matrix_flat, output reg done, output reg valid_partition, output reg [3:0] node_list, output reg [1:0] cycle_size);
  reg [3:0] adj_matrix [0:3];
  reg [3:0] counter;
  reg start_prev;
  wire two_cycles_valid;
  wire four_cycle_valid;
  wire valid_partition_combo;
  wire [3:0] node_list_combo;
  wire [1:0] cycle_size_combo;
  
  // Detect rising edge of start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_prev <= 1'b0;
    else start_prev <= start;
  end
  wire start_rise = start && !start_prev;
  
  // Combinatorial cycle checks
  wire [5:0] pair_valid;
  assign pair_valid[0] = adj_matrix[0][1] && adj_matrix[1][0];
  assign pair_valid[1] = adj_matrix[0][2] && adj_matrix[2][0];
  assign pair_valid[2] = adj_matrix[0][3] && adj_matrix[3][0];
  assign pair_valid[3] = adj_matrix[1][2] && adj_matrix[2][1];
  assign pair_valid[4] = adj_matrix[1][3] && adj_matrix[3][1];
  assign pair_valid[5] = adj_matrix[2][3] && adj_matrix[3][2];
  assign two_cycles_valid = (pair_valid[0] && pair_valid[5]) || (pair_valid[1] && pair_valid[4]) || (pair_valid[2] && pair_valid[3]);
  
  wire seq0 = adj_matrix[0][1] && adj_matrix[1][2] && adj_matrix[2][3] && adj_matrix[3][0];
  wire seq1 = adj_matrix[0][1] && adj_matrix[1][3] && adj_matrix[3][2] && adj_matrix[2][0];
  wire seq2 = adj_matrix[0][2] && adj_matrix[2][1] && adj_matrix[1][3] && adj_matrix[3][0];
  wire seq3 = adj_matrix[0][2] && adj_matrix[2][3] && adj_matrix[3][1] && adj_matrix[1][0];
  wire seq4 = adj_matrix[0][3] && adj_matrix[3][1] && adj_matrix[1][2] && adj_matrix[2][0];
  wire seq5 = adj_matrix[0][3] && adj_matrix[3][2] && adj_matrix[2][1] && adj_matrix[1][0];
  assign four_cycle_valid = seq0 || seq1 || seq2 || seq3 || seq4 || seq5;
  
  assign valid_partition_combo = !(two_cycles_valid || four_cycle_valid);
  assign node_list_combo = two_cycles_valid ? 
      ((pair_valid[0] && pair_valid[5]) ? 4'b0011 :
       (pair_valid[1] && pair_valid[4]) ? 4'b0101 :
       (pair_valid[2] && pair_valid[3]) ? 4'b1001 : 4'b0000) : 
      four_cycle_valid ? 4'b1111 : 4'b0000;
  assign cycle_size_combo = two_cycles_valid ? 2'd2 : (four_cycle_valid ? 2'd4 : 2'd0);
  
  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 4'd0;
      done <= 1'b0;
      valid_partition <= 1'b0;
      node_list <= 4'b0;
      cycle_size <= 2'b0;
      start_prev <= 1'b0;
      adj_matrix[0] <= 4'b0;
      adj_matrix[1] <= 4'b0;
      adj_matrix[2] <= 4'b0;
      adj_matrix[3] <= 4'b0;
    end else begin
      // Load adj_matrix on start_rise
      if (start_rise) begin
        adj_matrix[0] <= adj_matrix_flat[3:0];
        adj_matrix[1] <= adj_matrix_flat[7:4];
        adj_matrix[2] <= adj_matrix_flat[11:8];
        adj_matrix[3] <= adj_matrix_flat[15:12];
        counter <= 4'd0;
      end
      
      // Counter logic
      if (counter < 10) begin
        counter <= counter + 1;
        if (counter == 9) begin
          done <= 1'b1;
          valid_partition <= valid_partition_combo;
          node_list <= node_list_combo;
          cycle_size <= cycle_size_combo;
        end else done <= 1'b0;
      end else begin
        counter <= 4'd0;
        done <= 1'b0;
      end
    end
  end
endmodule