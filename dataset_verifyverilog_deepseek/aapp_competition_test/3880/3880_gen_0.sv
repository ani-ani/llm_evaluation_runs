module max_array_sum(input clk, input rst_n, input start, input [3:0] n_mode, input signed [15:0] data [14:0], output reg [15:0] max_sum, output reg done);
  reg [4:0] cycle_counter;
  reg [3:0] n_mode_latched;
  reg [19:0] sum_abs;
  reg [16:0] min_abs;
  reg [4:0] neg_count;
  reg condition;
  reg [19:0] temp_sub;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 5'd31;
      n_mode_latched <= 0;
      sum_abs <= 0;
      neg_count <= 0;
      min_abs <= 17'h1FFFF;
      condition <= 0;
      done <= 0;
      max_sum <= 0;
    end else begin
      if (start) begin
        cycle_counter <= 0;
        n_mode_latched <= n_mode;
        sum_abs <= 0;
        neg_count <= 0;
        min_abs <= 17'h1FFFF;
        done <= 0;
      end else if (cycle_counter < 20) begin
        cycle_counter <= cycle_counter + 1;
        
        // Processing phase (cycle 0-14)
        if (cycle_counter < 15) begin
          if (cycle_counter < (2*n_mode_latched - 1)) begin
            // Calculate absolute value
            reg [16:0] abs_val;
            abs_val = data[cycle_counter[3:0]][15] 
                      ? {1'b0, ~data[cycle_counter[3:0]]} + 17'd1 
                      : {1'b0, data[cycle_counter[3:0]]};
            
            sum_abs <= sum_abs + abs_val;
            neg_count <= neg_count + data[cycle_counter[3:0]][15];
            min_abs <= (abs_val < min_abs) ? abs_val : min_abs;
          end
        end 
        
        // Computation phase
        if (cycle_counter == 15) begin
          condition <= n_mode_latched[0] || !neg_count[0];
        end else if (cycle_counter == 16) begin
          temp_sub <= sum_abs - (min_abs << 1);
        end else if (cycle_counter == 17) begin
          max_sum <= condition ? sum_abs[15:0] : temp_sub[15:0];
        end else if (cycle_counter == 19) begin
          done <= 1;
        end
      end
    end
  end
endmodule