module pow_array (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [1:0] exponents,
  input wire [7:0] nums [0:9],
  input wire [9:0] valid_in,
  output reg [15:0] results [0:9],
  output reg [9:0] valid_out,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE    = 2'd0;
  localparam [1:0] COMPUTE = 2'd1;
  localparam [1:0] DONE_STATE = 2'd2;

  // Internal signals
  reg [1:0] state;
  reg [3:0] index;
  reg [31:0] temp_result;
  reg [31:0] x_squared;
  reg [31:0] x_cubed;
  reg [31:0] x_fifth;

  // Compute powers
  always @(*) begin
    // x^2
    x_squared = nums[index] * nums[index];
    
    // x^3
    x_cubed = x_squared * nums[index];
    
    // x^5
    x_fifth = x_squared * x_squared * nums[index];
  end

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      index <= 4'd0;
      done <= 1'b0;
      
      // Initialize all results and valid_out
      integer i;
      for (i = 0; i < 10; i = i + 1) begin
        results[i] <= 16'd0;
        valid_out[i] <= 1'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= COMPUTE;
            index <= 4'd0;
          end
        end

        COMPUTE: begin
          // Process current element
          if (valid_in[index]) begin
            case (exponents)
              2'd0: temp_result = x_squared;  // x^2
              2'd1: temp_result = x_cubed;   // x^3
              2'd2: temp_result = x_fifth;   // x^5
              default: temp_result = 16'd0;
            endcase
            
            // Saturate to 16 bits
            if (temp_result > 16'd65535) begin
              results[index] <= 16'd65535;
            end else begin
              results[index] <= temp_result[15:0];
            end
            valid_out[index] <= 1'b1;
          end else begin
            results[index] <= 16'd0;
            valid_out[index] <= 1'b0;
          end
          
          // Move to next element or finish
          if (index == 4'd9) begin
            state <= DONE_STATE;
          end else begin
            index <= index + 4'd1;
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule