module guitar_hero_scorer (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_notes,
  input [1:0] p_phrases,
  input [15:0] notes[0:15],
  input [15:0] sp_starts[0:3],
  input [15:0] sp_ends[0:3],
  output reg [7:0] max_score,
  output reg done
);
  
  reg [1:0] state;
  reg [4:0] combination;
  reg [7:0] next_max;
  
  localparam IDLE  = 2'd0;
  localparam PROC  = 2'd1;
  localparam FIN   = 2'd2;
  
  wire [3:0] max_combinations = (1 << p_phrases) - 1;
  wire [3:0] sp_mask = combination[3:0] & max_combinations;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_score <= 8'd0;
      done <= 1'b0;
      combination <= 5'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            max_score <= 8'd0;
            combination <= 5'd0;
            state <= PROC;
          end
        end
        
        PROC: begin
          if (combination[4]) begin
            state <= FIN;
          end else begin
            combination <= combination + 5'd1;
            if (next_max > max_score) max_score <= next_max;
          end
        end
        
        FIN: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
  
  always_comb begin
    reg [15:0] sel_starts[0:3];
    reg [15:0] sel_ends[0:3];
    integer i, j, valid_cnt = 0;
    
    // Collect selected SP phrases
    for (i = 0; i < 4; i = i + 1) begin
      if (sp_mask[i]) begin
        sel_starts[valid_cnt] = sp_starts[i];
        sel_ends[valid_cnt]   = sp_ends[i];
        valid_cnt = valid_cnt + 1;
      end
    end
    
    // Bubble sort selected phrases
    for (i = 0; i < valid_cnt; i = i + 1) begin
      for (j = i + 1; j < valid_cnt; j = j + 1) begin
        if (sel_starts[j] < sel_starts[i]) begin
          reg [15:0] tmp_s = sel_starts[i];
          reg [15:0] tmp_e = sel_ends[i];
          sel_starts[i] = sel_starts[j];
          sel_ends[i]   = sel_ends[j];
          sel_starts[j] = tmp_s;
          sel_ends[j]   = tmp_e;
        end
      end
    end
    
    // Merge overlapping intervals
    reg [15:0] merged_starts[0:3];
    reg [15:0] merged_ends[0:3];
    integer merge_cnt = 0;
    
    if (valid_cnt > 0) begin
      merged_starts[0] = sel_starts[0];
      merged_ends[0]   = sel_ends[0];
      merge_cnt = 1;
      
      for (i = 1; i < valid_cnt; i = i + 1) begin
        if (sel_starts[i] <= merged_ends[merge_cnt-1]) begin
          if (sel_ends[i] > merged_ends[merge_cnt-1])
            merged_ends[merge_cnt-1] = sel_ends[i];
        end else begin
          merged_starts[merge_cnt] = sel_starts[i];
          merged_ends[merge_cnt]   = sel_ends[i];
          merge_cnt = merge_cnt + 1;
        end
      end
    end
    
    // Calculate score
    next_max = 0;
    for (i = 0; i < n_notes; i = i + 1) begin
      reg in_sp = 0;
      for (j = 0; j < merge_cnt; j = j + 1) begin
        if (notes[i] >= merged_starts[j] && notes[i] <= merged_ends[j]) begin
          in_sp = 1;
          break;
        end
      end
      next_max = next_max + (in_sp ? 8'd2 : 8'd1);
    end
  end
endmodule