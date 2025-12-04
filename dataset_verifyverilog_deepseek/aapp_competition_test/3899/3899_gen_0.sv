module task_threshold(
  input clk,
  input rst_n,
  input start,
  input [31:0] power [0:3],
  input [7:0] processors [0:3],
  output reg [31:0] result,
  output reg done
);

  // Internal registers
  logic [31:0] s_power [0:3];
  logic [7:0] s_procs [0:3];
  reg [2:0] state;
  reg [3:0] mask;
  reg [31:0] min_thresh;
  reg [5:0] counter;
  
  // States
  localparam IDLE = 3'd0;
  localparam SORT = 3'd1;
  localparam CALC = 3'd2;
  localparam FINISH = 3'd3;
  
  // Combinatorial sorting network
  always_comb begin
    s_power = power;
    s_procs = processors;
    
    // Insertion sort (3 stages)
    for (int i=0; i<3; i++) begin
      for (int j=0; j<3-i; j++) begin
        if (s_power[j] < s_power[j+1]) begin
          automatic logic [31:0] tmp_p = s_power[j];
          automatic logic [7:0] tmp_c = s_procs[j];
          s_power[j] = s_power[j+1];
          s_procs[j] = s_procs[j+1];
          s_power[j+1] = tmp_p;
          s_procs[j+1] = tmp_c;
        end
      end
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      min_thresh <= 32'hFFFFFFFF;
      mask <= 4'h0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= SORT;
            counter <= 0;
            min_thresh <= 32'hFFFFFFFF;
          end
        end
        
        SORT: begin
          state <= CALC;
          mask <= 4'h1;  // Skip empty set
          counter <= 0;
        end
        
        CALC: begin
          automatic logic [31:0] sum_power = 0;
          automatic logic [31:0] sum_procs = 0;
          
          // Calculate current mask sums
          for (int i=0; i<4; i++) begin
            if (mask[i]) begin
              sum_power += s_power[i];
              sum_procs += s_procs[i];
            end
          end
          
          if (sum_procs != 0) begin
            automatic logic [31:0] threshold = (sum_power * 1000 + sum_procs - 1) / sum_procs;
            if (threshold < min_thresh) min_thresh <= threshold;
          end
          
          if (mask == 4'hF) begin
            state <= FINISH;
            result <= min_thresh;
          end else begin
            mask <= mask + 1;
          end
          counter <= counter + 1;
        end
        
        FINISH: begin
          if (counter < 49) counter <= counter + 1;
          else begin
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule