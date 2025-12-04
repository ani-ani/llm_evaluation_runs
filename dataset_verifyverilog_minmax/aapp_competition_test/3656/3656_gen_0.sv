module bug_fix_predictor(
  input clk,
  input rst_n,
  input start,
  input [15:0] f,
  input [15:0] p [2],
  input [13:0] s [2],
  output reg [31:0] expected_severity,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  
  reg [1:0] state;
  reg [1:0] cycle;
  reg [31:0] V2_0, V2_1, V2_2, V2_3;
  reg [31:0] V1_0, V1_1, V1_2;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      expected_severity <= 32'b0;
      cycle <= 2'b0;
      V2_0 <= 32'b0;
      V2_1 <= 32'b0;
      V2_2 <= 32'b0;
      V2_3 <= 32'b0;
      V1_0 <= 32'b0;
      V1_1 <= 32'b0;
      V1_2 <= 32'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            cycle <= 2'b0;
            done <= 1'b0;
          end
        end
        
        COMPUTE: begin
          case (cycle)
            2'b00: begin
              // Cycle 0: Compute base cases for t=2, state 0 and 1
              V2_0 <= 32'b0;  // no fixed bugs, max severity is 0
              V2_1 <= {18'b0, s[0]} << 16;  // fixed bug0, severity s0 in Q16.16
              cycle <= 2'b01;
            end
            
            2'b01: begin
              // Cycle 1: Compute base cases for t=2, state 2 and 3
              V2_2 <= {18'b0, s[1]} << 16;  // fixed bug1, severity s1 in Q16.16
              V2_3 <= (s[0] > s[1]) ? ({18'b0, s[0]} << 16) : ({18'b0, s[1]} << 16);  // max of s0 and s1
              cycle <= 2'b10;
            end
            
            2'b10: begin
              // Cycle 2: Compute V(1,0) and V(1,1)
              // V(1,0) = max(p0*V2_1 + (1-p0)*V2_0, p1*V2_2 + (1-p1)*V2_0)
              begin
                longint branch0 = (longint)p[0] * V2_1 + (longint)((32'h00010000) - (longint)p[0]) * V2_0;
                longint branch1 = (longint)p[1] * V2_2 + (longint)((32'h00010000) - (longint)p[1]) * V2_0;
                V1_0 <= (branch0 > branch1) ? (branch0 >> 16) : (branch1 >> 16);
              end
              
              // V(1,1) = p1*V2_3 + (1-p1)*V2_1
              begin
                longint branch1_1 = (longint)p[1] * V2_3 + (longint)((32'h00010000) - (longint)p[1]) * V2_1;
                V1_1 <= branch1_1 >> 16;
              end
              
              cycle <= 2'b11;
            end
            
            2'b11: begin
              // Cycle 3: Compute V(1,2) and V(0,0)
              // V(1,2) = p0*V2_3 + (1-p0)*V2_2
              begin
                longint branch1_2 = (longint)p[0] * V2_3 + (longint)((32'h00010000) - (longint)p[0]) * V2_2;
                V1_2 <= branch1_2 >> 16;
              end
              
              // V(0,0) = max(p0*V1_1 + (1-p0)*V1_0, p1*V1_2 + (1-p1)*V1_0)
              begin
                longint branch0_0 = (longint)p[0] * V1_1 + (longint)((32'h00010000) - (longint)p[0]) * V1_0;
                longint branch1_0 = (longint)p[1] * V1_2 + (longint)((32'h00010000) - (longint)p[1]) * V1_0;
                expected_severity <= (branch0_0 > branch1_0) ? (branch0_0 >> 16) : (branch1_0 >> 16);
              end
              
              done <= 1'b1;
              state <= IDLE;
            end
            
            default: begin
              state <= IDLE;
              cycle <= 2'b0;
            end
          endcase
        end
        
        default: begin
          state <= IDLE;
          cycle <= 2'b0;
        end
      endcase
    end
  end

endmodule