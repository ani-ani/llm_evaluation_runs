module tuple_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuples [0:7][1:0],
  input [3:0] tuple_count,
  output reg [7:0] unique_tuples [0:7][1:0],
  output reg [3:0] counts [0:7],
  output reg [3:0] unique_count,
  output reg done
);

  reg [1:0] state;
  localparam IDLE = 2'd0;
  localparam SORT = 2'd1;
  localparam COUNT = 2'd2;
  localparam DONE = 2'd3;
  
  reg [3:0] sort_idx;
  reg [3:0] count_idx;
  reg [7:0] sorted_tuples [0:7][1:0];
  
  reg match_found;
  reg [2:0] match_index;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      sort_idx <= 0;
      count_idx <= 0;
      unique_count <= 0;
      foreach (unique_tuples[i,j]) unique_tuples[i][j] <= 8'b0;
      foreach (counts[i]) counts[i] <= 4'b0;
      foreach (sorted_tuples[i,j]) sorted_tuples[i][j] <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORT;
            sort_idx <= 0;
            done <= 0;
            unique_count <= 0;
            foreach (unique_tuples[i,j]) unique_tuples[i][j] <= 8'b0;
            foreach (counts[i]) counts[i] <= 4'b0;
          end
        end
        
        SORT: begin
          if (sort_idx < tuple_count) begin
            if (tuples[sort_idx][0] <= tuples[sort_idx][1]) begin
              sorted_tuples[sort_idx][0] <= tuples[sort_idx][0];
              sorted_tuples[sort_idx][1] <= tuples[sort_idx][1];
            end else begin
              sorted_tuples[sort_idx][0] <= tuples[sort_idx][1];
              sorted_tuples[sort_idx][1] <= tuples[sort_idx][0];
            end
            sort_idx <= sort_idx + 1;
          end else begin
            state <= COUNT;
            count_idx <= 0;
          end
        end
        
        COUNT: begin
          if (count_idx < tuple_count) begin
            if (match_found) begin
              counts[match_index] <= counts[match_index] + 1;
            end else if (unique_count < 8) begin
              unique_tuples[unique_count][0] <= sorted_tuples[count_idx][0];
              unique_tuples[unique_count][1] <= sorted_tuples[count_idx][1];
              counts[unique_count] <= 4'd1;
              unique_count <= unique_count + 1;
            end
            count_idx <= count_idx + 1;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end
        
        DONE: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end
  
  always_comb begin
    match_found = 0;
    match_index = 0;
    if (state == COUNT && count_idx < tuple_count) begin
      for (int i = 0; i < unique_count; i++) begin
        if (sorted_tuples[count_idx][0] == unique_tuples[i][0] && 
            sorted_tuples[count_idx][1] == unique_tuples[i][1]) begin
          match_found = 1;
          match_index = i;
        end
      end
    end
  end
  
endmodule