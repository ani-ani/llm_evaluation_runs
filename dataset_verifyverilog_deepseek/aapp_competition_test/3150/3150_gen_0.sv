module guard_placement_calc (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_trenches,
  input [15:0][39:0] trenches,
  output reg [15:0] result_count,
  output reg done
);

typedef enum logic [1:0] {IDLE, LOAD, PROCESS, DONE} state_t;
state_t current_state, next_state;

reg [39:0] trench_reg [0:15];
reg [15:0] line_mask [0:15];
reg [15:0] count_reg;
reg [3:0] i_reg, j_reg, k_reg;
reg [4:0] num_trenches_reg;
reg start_prev;

wire start_posedge = ~start_prev & start;

always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    current_state <= IDLE;
    start_prev <= 0;
    count_reg <= 0;
    done <= 0;
    for (int i=0; i<16; i++) begin
      trench_reg[i] <= 0;
      line_mask[i] <= 0;
    end
    i_reg <= 4'd0;
    j_reg <= 4'd1;
    k_reg <= 4'd2;
    num_trenches_reg <= 0;
  end else begin
    current_state <= next_state;
    start_prev <= start;
    
    case (current_state)
      IDLE: begin
        if (start_posedge) begin
          num_trenches_reg <= num_trenches;
          for (int idx=0; idx<16; idx++) begin
            trench_reg[idx] <= trenches[idx];
          end
        end
        done <= 0;
        count_reg <= 0;
      end
      
      LOAD: begin
        for (int i=0; i<16; i++) begin
          for (int m=0; m<16; m++) begin
            reg [9:0] x1_m = trench_reg[m][39:30];
            reg [9:0] y1_m = trench_reg[m][29:20];
            reg [9:0] x2_m = trench_reg[m][19:10];
            reg [9:0] y2_m = trench_reg[m][9:0];
            
            reg signed [10:0] dx = $signed(x2_m) - $signed(x1_m);
            reg signed [10:0] dy = $signed(y2_m) - $signed(y1_m);
            
            reg [9:0] x1_i = trench_reg[i][39:30];
            reg [9:0] y1_i = trench_reg[i][29:20];
            reg [9:0] x2_i = trench_reg[i][19:10];
            reg [9:0] y2_i = trench_reg[i][9:0];
            
            reg signed [21:0] temp1 = ($signed(y1_i) - $signed(y1_m)) * dx;
            reg signed [21:0] temp2 = ($signed(x1_i) - $signed(x1_m)) * dy;
            reg p1_match = (temp1 == temp2);
            
            reg signed [21:0] temp3 = ($signed(y2_i) - $signed(y1_m)) * dx;
            reg signed [21:0] temp4 = ($signed(x2_i) - $signed(x1_m)) * dy;
            reg p2_match = (temp3 == temp4);
            
            line_mask[i][m] <= p1_match | p2_match;
          end
        end
        i_reg <= 0;
        j_reg <= 1;
        k_reg <= 2;
      end
      
      PROCESS: begin
        if (num_trenches_reg >= 3 && i_reg < num_trenches_reg && j_reg < num_trenches_reg && k_reg < num_trenches_reg) begin
          if (line_mask[i_reg] & line_mask[j_reg] & line_mask[k_reg] != 16'd0) begin
            count_reg <= count_reg + 1;
          end
        end
        
        if (k_reg < (num_trenches_reg-1)) begin
          k_reg <= k_reg + 1;
        end else begin
          k_reg <= j_reg + 2;
          if (j_reg < (num_trenches_reg-2)) begin
            j_reg <= j_reg + 1;
          end else begin
            j_reg <= i_reg + 2;
            if (i_reg < (num_trenches_reg-3)) begin
              i_reg <= i_reg + 1;
            end else begin
              i_reg <= i_reg;
            end
          end
        end
      end
      
      DONE: begin
        done <= 1;
      end
    endcase
  end
end

always_comb begin
  case (current_state)
    IDLE: next_state = (start_posedge) ? LOAD : IDLE;
    LOAD: next_state = PROCESS;
    PROCESS: next_state = ((i_reg >= (num_trenches_reg-3)) && (j_reg >= (num_trenches_reg-2)) && (k_reg >= (num_trenches_reg-1))) ? DONE : PROCESS;
    DONE: next_state = (start_posedge) ? LOAD : DONE;
    default: next_state = IDLE;
  endcase
end

assign result_count = count_reg;

endmodule