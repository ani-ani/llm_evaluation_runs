module frog_jump_calculator(
  input clk,
  input rst_n,
  input [1:0] cmd_type,
  input [15:0] cmd_data,
  input cmd_valid,
  output reg [4:0] total_jumps,
  output reg result_valid
);

  // State registers
  reg [15:0] frog_positions [0:7];
  reg [3:0] frog_count;
  reg [15:0] current_target;
  
  // Pipeline control
  reg compute_enable;
  reg [4:0] total_jumps_reg;
  
  // Compute k function
  function automatic [4:0] compute_k(input [15:0] dist);
    begin
      compute_k = 31;
      for (int k=0; k<=31; k++) begin
        logic [31:0] t = (k * (k+1)) >> 1;
        if (t >= dist && k[0] == dist[0] && k < compute_k) begin
          compute_k = k;
        end
      end
    end
  endfunction
  
  // Jump calculation comb logic
  logic [4:0] max_k;
  always_comb begin
    max_k = 0;
    for (int i=0; i<8; i++) begin
      if (i < frog_count) begin
        logic [15:0] pos = frog_positions[i];
        logic [15:0] dist = (pos >= current_target) ? (pos - current_target) : (current_target - pos);
        logic [4:0] k = compute_k(dist);
        if (k > max_k) max_k = k;
      end
    end
  end
  
  // Command processing and state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frog_count <= 4'd0;
      current_target <= 16'd0;
      compute_enable <= 1'b0;
      total_jumps <= 5'd0;
      result_valid <= 1'b0;
    end else begin
      // Default assignments
      compute_enable <= cmd_valid;
      result_valid <= 1'b0;
      
      // Process commands
      if (cmd_valid) begin
        case(cmd_type)
          2'b00: begin // Add frog
            if (frog_count < 8) begin
              frog_positions[frog_count] <= cmd_data;
              frog_count <= frog_count + 1;
            end
          end
          2'b01: begin // Remove frog
            for (int i=0; i<8; i++) begin
              if (i < frog_count && frog_positions[i] == cmd_data) begin
                for (int j=i; j<7; j++) begin
                  frog_positions[j] <= frog_positions[j+1];
                end
                frog_positions[7] <= 16'd0;
                frog_count <= frog_count - 1;
                break;
              end
            end
          end
          2'b10: begin // Change target
            current_target <= cmd_data;
          end
        endcase
      end
      
      // Pipeline stage - capture results
      if (compute_enable) begin
        total_jumps <= max_k;
        result_valid <= 1'b1;
      end
    end
  end

endmodule