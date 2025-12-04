module trade_matcher(
  input clk,
  input rst_n,
  input start,
  input [3:0] i,
  input [3:0] j,
  output reg [3:0] max_length,
  output reg done
);
  reg [7:0] s [0:15] = '{"A","B","A","B","A","B","c","A","B","A","B","A","b","A","b","a"};
  reg [3:0] i_reg, j_reg;
  reg start_d;
  reg [1:0] state;
  wire start_rising = start && !start_d;
  
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE_ST = 2'b10;
  
  logic [15:0] match;
  logic [3:0] temp_max;
  
  generate
    genvar k;
    assign match[0] = ((i_reg <= 4'd15) && (j_reg <= 4'd15) && (s[i_reg] == s[j_reg]));
    for (k = 1; k < 16; k++) begin : gen_match
      assign match[k] = match[k-1] && ((i_reg + k) < 16) && ((j_reg + k) < 16) && (s[i_reg + k] == s[j_reg + k]);
    end
  endgenerate
  
  // Compute max_length
  always_comb begin
    temp_max = 16;
    for (int m = 0; m < 16; m++) begin
      if (!match[m]) begin
        temp_max = m[3:0];
      end
    end
  end
  
  // FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_length <= 0;
      start_d <= 0;
      i_reg <= 0;
      j_reg <= 0;
    end else begin
      start_d <= start;
      
      case(state)
        IDLE: begin
          done <= 0;
          if (start_rising) begin
            i_reg <= i;
            j_reg <= j;
            state <= COMPUTE;
          end
        end
        
        COMPUTE: begin
          state <= DONE_ST;
        end 
        
        DONE_ST: begin
          max_length <= temp_max;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule