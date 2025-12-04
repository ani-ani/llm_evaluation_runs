module license_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [7:0] s1,
  input [7:0] s2,
  input [7:0] t [0:15],
  output reg [3:0] max_customers,
  output reg done
);

  reg [1:0] state;
  localparam IDLE   = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE   = 2'b10;
  
  reg [3:0] customer_index;
  reg [255:0] current_dp [0:255];
  wire [255:0] next_dp_image [0:255];
  wire [7:0] t_current = t[customer_index];
  
  // Row reduction OR
  wire [255:0] row_ors;
  generate
    genvar i,j;
    for (i=0; i<256; i=i+1) begin: gen_row
      for (j=0; j<256; j=j+1) begin: gen_col
        assign next_dp_image[i][j] = ((i + t_current <= 8'hff) && current_dp[i + t_current][j]) ||
                                     ((j + t_current <= 8'hff) && current_dp[i][j + t_current]);
      end
      assign row_ors[i] = |next_dp_image[i];
    end
  endgenerate
  
  wire dp_non_empty = |row_ors;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_customers <= 4'b0;
      customer_index <= 4'b0;
      for (int i=0; i<256; i++) begin
        current_dp[i] <= 256'b0;
      end
    end else begin
      done <= 1'b0;
      
      case (state)
        IDLE: begin
          if (start) begin
            max_customers <= 4'b0;
            if (n == 4'b0) begin
              state <= DONE;
              done <= 1'b1;
            end else begin
              // Initialize DP table
              for (int i=0; i<256; i++) begin
                current_dp[i] <= 256'b0;
              end
              current_dp[s1][s2] <= 1'b1;
              customer_index <= 4'b0;
              state <= PROCESSING;
            end
          end
        end
        
        PROCESSING: begin
          // Update DP table
          for (int i=0; i<256; i++) begin
            current_dp[i] <= next_dp_image[i];
          end
          
          // Update max_customers if valid state exists
          if (dp_non_empty) begin
            max_customers <= customer_index + 1'b1;
          end
          
          // Advance state
          if (customer_index == (n-1)) begin
            state <= DONE;
            done <= 1'b1;
          end else begin
            customer_index <= customer_index + 1'b1;
          end
        end
        
        DONE: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule