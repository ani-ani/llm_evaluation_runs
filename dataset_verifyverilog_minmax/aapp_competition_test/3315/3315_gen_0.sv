module loda_teleportations (
  input clk,
  input rst_n,
  input start,
  input [7:0] string_count,
  input [15:0][7:0] strings [0:7],
  input [4:0] lengths [0:7],
  output reg [3:0] max_length,
  output reg done
);

  // State definitions
  localparam IDLE = 3'd0;
  localparam PREFIX = 3'd1;
  localparam SUFFIX = 3'd2;
  localparam COMP = 3'd3;
  localparam DP = 3'd4;
  localparam DONE = 3'd5;

  // State variables
  reg [2:0] state;
  reg [3:0] char_idx;
  reg [3:0] node_idx;
  
  // Matrix registers
  reg [7:0][7:0] prefix_matrix;
  reg [7:0][7:0] suffix_matrix;
  reg [7:0][7:0] compat_matrix;
  
  // DP array
  reg [3:0] dp [0:7];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      prefix_matrix <= 8'd0;
      suffix_matrix <= 8'd0;
      compat_matrix <= 8'd0;
      char_idx <= 4'd0;
      node_idx <= 4'd0;
      max_length <= 4'd0;
      for (int i = 0; i < 8; i++) begin
        dp[i] <= 4'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREFIX;
            char_idx <= 4'd0;
          end
        end
        
        PREFIX: begin
          if (char_idx == 4'd0) begin
            // Initialize prefix matrix for first character
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 8; j++) begin
                if (i < j && i < string_count && j < string_count && 
                    lengths[i] <= lengths[j] && 
                    strings[i][0] == strings[j][0]) begin
                  prefix_matrix[i][j] <= 1'b1;
                end else begin
                  prefix_matrix[i][j] <= 1'b0;
                end
              end
            end
          end else begin
            // Update based on current character
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 8; j++) begin
                if (i < j && i < string_count && j < string_count) begin
                  if (prefix_matrix[i][j] && 
                      char_idx < lengths[i] && char_idx < lengths[j] &&
                      strings[i][char_idx] == strings[j][char_idx]) begin
                    prefix_matrix[i][j] <= 1'b1;
                  end else begin
                    prefix_matrix[i][j] <= 1'b0;
                  end
                end else begin
                  prefix_matrix[i][j] <= 1'b0;
                end
              end
            end
          end
          
          char_idx <= char_idx + 1;
          if (char_idx == 4'd15) begin
            state <= SUFFIX;
            char_idx <= 4'd0;
          end
        end
        
        SUFFIX: begin
          if (char_idx == 4'd0) begin
            // Initialize suffix matrix for first character
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 8; j++) begin
                if (i < j && i < string_count && j < string_count && 
                    lengths[i] <= lengths[j] && 
                    strings[i][0] == strings[j][lengths[j]-lengths[i]]) begin
                  suffix_matrix[i][j] <= 1'b1;
                end else begin
                  suffix_matrix[i][j] <= 1'b0;
                end
              end
            end
          end else begin
            // Update based on current character
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 8; j++) begin
                if (i < j && i < string_count && j < string_count) begin
                  if (suffix_matrix[i][j] && 
                      char_idx < lengths[i] && char_idx < lengths[j] &&
                      strings[i][char_idx] == strings[j][lengths[j]-lengths[i]+char_idx]) begin
                    suffix_matrix[i][j] <= 1'b1;
                  end else begin
                    suffix_matrix[i][j] <= 1'b0;
                  end
                end else begin
                  suffix_matrix[i][j] <= 1'b0;
                end
              end
            end
          end
          
          char_idx <= char_idx + 1;
          if (char_idx == 4'd15) begin
            state <= COMP;
            char_idx <= 4'd0;
          end
        end
        
        COMP: begin
          // Compute compatibility matrix
          for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
              compat_matrix[i][j] <= prefix_matrix[i][j] & suffix_matrix[i][j];
            end
          end
          
          // Initialize DP array
          for (int i = 0; i < 8; i++) begin
            if (i < string_count) begin
              dp[i] <= 4'd1;
            end else begin
              dp[i] <= 4'd0;
            end
          end
          
          node_idx <= 4'd0;
          state <= DP;
        end
        
        DP: begin
          if (node_idx < string_count) begin
            // Update dp for current node
            reg [3:0] max_val;
            max_val = 1; // Base case: node itself
            
            for (int i = 0; i < node_idx; i++) begin
              if (compat_matrix[i][node_idx] && i < string_count) begin
                if (dp[i] + 1 > max_val) begin
                  max_val = dp[i] + 1;
                end
              end
            end
            
            dp[node_idx] <= max_val;
            node_idx <= node_idx + 1;
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          // Find maximum path length
          max_length <= 0;
          for (int i = 0; i < 8; i++) begin
            if (i < string_count && dp[i] > max_length) begin
              max_length <= dp[i];
            end
          end
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule