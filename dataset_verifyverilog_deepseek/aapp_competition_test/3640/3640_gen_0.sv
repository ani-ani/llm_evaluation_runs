module meow_factor(
  input clk,
  input rst_n,
  input start,
  input [39:0] str_in,
  output reg [3:0] min_ops,
  output reg done
);

  localparam M = 5'h0D; // 'm'
  localparam E = 5'h05; // 'e'
  localparam O = 5'h0F; // 'o'
  localparam W = 5'h17; // 'w'

  reg [1:0] state;
  reg [39:0] str_in_reg;
  reg [3:0] min_ops_next;
  
  localparam IDLE    = 2'h0;
  localparam CALCULATE = 2'h1;
  localparam DONE    = 2'h2;

  wire [3:0] window_cost [0:4];
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_ops <= 4'b0;
      str_in_reg <= 40'b0;
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= CALCULATE;
            str_in_reg <= str_in;
          end
        end
        CALCULATE: begin
          state <= DONE;
          min_ops <= min_ops_next;
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= CALCULATE;
            str_in_reg <= str_in;
          end else begin
            state <= DONE;
          end
        end
      endcase
    end
  end

  // Window cost calculation
  generate
    genvar i;
    for (i=0; i<5; i=i+1) begin : calc_window
      wire [4:0] char0 = str_in_reg[39 - i*5 -: 5];
      wire [4:0] char1 = str_in_reg[39 - (i+1)*5 -: 5];
      wire [4:0] char2 = str_in_reg[39 - (i+2)*5 -: 5];
      wire [4:0] char3 = str_in_reg[39 - (i+3)*5 -: 5];
      
      wire mismatch0 = (char0 != M);
      wire mismatch1 = (char1 != E);
      wire mismatch2 = (char2 != O);
      wire mismatch3 = (char3 != W);
      
      wire [3:0] base_cost = mismatch0 + mismatch1 + mismatch2 + mismatch3;
      
      wire swap01_ok = (char0 == E) && (char1 == M);
      wire swap12_ok = (char1 == O) && (char2 == E);
      wire swap23_ok = (char2 == W) && (char3 == O);
      
      wire [1:0] optionA = {1'b0, swap01_ok} + {1'b0, swap23_ok};
      wire optionB = swap12_ok;
      wire [1:0] swap_save = (optionA > {1'b0, optionB}) ? optionA : {1'b0, optionB};
      
      assign window_cost[i] = base_cost - swap_save;
    end
  endgenerate

  // Comparator tree
  wire [3:0] min01 = (window_cost[0] < window_cost[1]) ? window_cost[0] : window_cost[1];
  wire [3:0] min23 = (window_cost[2] < window_cost[3]) ? window_cost[2] : window_cost[3];
  wire [3:0] min0123 = (min01 < min23) ? min01 : min23;
  wire [3:0] min_cost = (min0123 < window_cost[4]) ? min0123 : window_cost[4];
  
  // Output assignment
  assign min_ops_next = min_cost;

endmodule