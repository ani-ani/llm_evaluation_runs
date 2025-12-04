module dog_chain_calculator(
  input clk,
  input rst_n,
  input start,
  input [11:0] L,
  output reg [7:0] chain_length,
  output reg done
);

  // Internal registers
  reg [11:0] L_reg;
  reg [19:0] temp; // L * 226 (12-bit * 8-bit = 20-bit)
  reg [19:0] current_value; // For division calculations
  reg [2:0] quotient; // Max value 3 (from 3 subtractions)
  reg [3:0] state; // State machine state (0-10)
  
  // State machine states
  localparam IDLE = 4'd0;
  localparam MULT = 4'd1;
  localparam DIV0 = 4'd2;
  localparam WAIT0 = 4'd3;
  localparam DIV1 = 4'd4;
  localparam WAIT1 = 4'd5;
  localparam DIV2 = 4'd6;
  localparam WAIT2 = 4'd7;
  localparam DIV3 = 4'd8;
  localparam SQRT = 4'd9;
  localparam DONE = 4'd10;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      state <= IDLE;
      L_reg <= 0;
      temp <= 0;
      current_value <= 0;
      quotient <= 0;
      chain_length <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            L_reg <= L;
            state <= MULT;
          end
        end
        
        MULT: begin
          // Calculate temp = L * 226
          temp <= L_reg * 226;
          state <= DIV0;
        end
        
        DIV0: begin
          // Initialize for division: current_value = temp + 354 (for ceil division)
          current_value <= temp + 354;
          quotient <= 0;
          state <= WAIT0;
        end
        
        WAIT0: begin
          // First wait state
          state <= DIV1;
        end
        
        DIV1: begin
          // First subtraction (count 1 if possible)
          if (current_value >= 355) begin
            current_value <= current_value - 355;
            quotient <= 1;
          end else begin
            quotient <= 0;
          end
          state <= WAIT1;
        end
        
        WAIT1: begin
          // Second wait state
          state <= DIV2;
        end
        
        DIV2: begin
          // Second subtraction (add to count if possible)
          if (current_value >= 355) begin
            current_value <= current_value - 355;
            quotient <= quotient + 1;
          end
          state <= WAIT2;
        end
        
        WAIT2: begin
          // Third wait state
          state <= DIV3;
        end
        
        DIV3: begin
          // Third subtraction (add to count if possible)
          if (current_value >= 355) begin
            current_value <= current_value - 355;
            quotient <= quotient + 1;
          end
          state <= SQRT;
        end
        
        SQRT: begin
          // Calculate ceiling of square root of quotient
          // Since quotient is 0-3, we can use direct mapping
          case (quotient)
            3'd0: chain_length <= 8'd0;
            3'd1: chain_length <= 8'd1;
            3'd2: chain_length <= 8'd2;
            3'd3: chain_length <= 8'd2; // ceil(sqrt(3)) = 2
            default: chain_length <= 8'd0;
          endcase
          done <= 1; // Assert done for 1 cycle
          state <= DONE;
        end
        
        DONE: begin
          done <= 0; // Deassert done
          state <= IDLE; // Return to IDLE for next computation
        end
        
        default: state <= IDLE; // Default to IDLE for safety
      endcase
    end
  end
  
endmodule