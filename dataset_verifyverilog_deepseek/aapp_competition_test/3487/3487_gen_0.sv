module fluid_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] v,
  input [15:0] a,
  input [2:0] pipe_j [0:15],
  input [2:0] pipe_k [0:15],
  input [7:0] pipe_cap [0:15],
  input [3:0] p,
  output reg [15:0] flubber_rates [0:15],
  output reg [15:0] water_rates [0:15],
  output reg [15:0] optimal_value,
  output reg done
);

  localparam STEP_SIZE = 16'h0010; // Q8.8 step size (0.0625)
  reg [7:0] iteration;
  reg running;
  
  // Intermediate state registers
  reg [15:0] flubber_temp [0:15];
  reg [15:0] water_temp [0:15];
  
  // Flow conservation buffers
  reg [15:0] node_flow_diff [0:7]; // Supports up to 8 nodes
  
  integer i, idx;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      running <= 1'b0;
      iteration <= 8'd0;
      optimal_value <= 16'd0;
      
      for (i = 0; i < 16; i++) begin
        flubber_rates[i] <= 16'd0;
        water_rates[i] <= 16'd0;
        flubber_temp[i] <= 16'd0;
        water_temp[i] <= 16'd0;
      end
      
      for (i = 0; i < 8; i++) node_flow_diff[i] <= 16'd0;
    end else begin
      if (start && !running) begin
        running <= 1'b1;
        iteration <= 8'd0;
        done <= 1'b0;
      end
      
      if (running) begin
        if (iteration < 8'd255) begin
          iteration <= iteration + 8'd1;
          
          // Phase 1: Gradient update
          for (i = 0; i < p; i++) begin
            // Simplified gradient step
            flubber_temp[i] <= flubber_rates[i] + STEP_SIZE;
            water_temp[i] <= water_rates[i] + STEP_SIZE;
          end
          
          // Phase 2: Capacity enforcement
          for (i = 0; i < p; i++) begin
            reg [31:0] product;
            reg [15:0] cap_scaled;
            
            product = v * flubber_temp[i]; // Q8.8 * Q8.8 = Q16.16
            cap_scaled = {pipe_cap[i], 8'h00}; // Convert to Q8.8
            
            if ((product[23:8] + water_temp[i]) > cap_scaled) begin
              flubber_rates[i] <= flubber_rates[i]; // Revert
              water_rates[i] <= water_rates[i];
            end else begin
              flubber_rates[i] <= flubber_temp[i];
              water_rates[i] <= water_temp[i];
            end
          end
          
          // Phase 3: Flow conservation (simplified averaging)
          // Reset diff buffers
          for (idx = 0; idx < 8; idx++) node_flow_diff[idx] <= 16'd0;
          
          // Calculate violations
          for (i = 0; i < p; i++) begin
            if (pipe_j[i] > 3) begin // Exclude special nodes
              node_flow_diff[pipe_j[i]] <= node_flow_diff[pipe_j[i]] - (flubber_rates[i] + water_rates[i]);
            end
            if (pipe_k[i] > 3) begin
              node_flow_diff[pipe_k[i]] <= node_flow_diff[pipe_k[i]] + (flubber_rates[i] + water_rates[i]);
            end
          end
          
          // Apply balancing (simplified)
          for (i = 0; i < p; i++) begin
            if (pipe_j[i] > 3) begin
              flubber_rates[i] <= flubber_rates[i] + node_flow_diff[pipe_j[i]][15:8];
              water_rates[i] <= water_rates[i] + node_flow_diff[pipe_j[i]][7:0];
            end
          end
          
        end else begin
          // Final iteration
          running <= 1'b0;
          done <= 1'b1;
          
          // Calculate F^a * W^(1-a)
          reg [15:0] F_sum = 16'd0;
          reg [15:0] W_sum = 16'd0;
          for (i = 0; i < p; i++) begin
            if (pipe_k[i] == 3'd3) begin // Assuming node3 is FD
              F_sum = F_sum + flubber_rates[i];
              W_sum = W_sum + water_rates[i];
            end
          end
          
          // Simplified fixed-point exponentiation (placeholder)
          optimal_value <= (F_sum > 0 && W_sum > 0) ? F_sum : 16'd0;
        end
      end
    end
  end
endmodule