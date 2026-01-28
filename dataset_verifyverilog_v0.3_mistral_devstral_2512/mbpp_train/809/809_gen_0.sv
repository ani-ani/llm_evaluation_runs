module tuple_comparator(
  input clk,
  input rst_n,
  input start,
  input [7:0] tup1_0, tup1_1, tup1_2, tup1_3, tup1_4, tup1_5, tup1_6, tup1_7,
  input [7:0] tup2_0, tup2_1, tup2_2, tup2_3, tup2_4, tup2_5, tup2_6, tup2_7,
  input [2:0] len,
  output reg result,
  output reg done
);

  // State declarations
  localparam [1:0] IDLE    = 2'd0;
  localparam [1:0] COMPARE = 2'd1;
  localparam [1:0] FINISH  = 2'd2;
  
  // Internal signals
  reg [1:0] state;
  reg [2:0] index;
  reg [7:0] cycle_count;
  localparam [7:0] MAX_CYCLES = 8'd100;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 3'd0;
      result <= 1'b0;
      done <= 1'b0;
      cycle_count <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_count <= 8'd0;
          if (start) begin
            state <= COMPARE;
            index <= 3'd0;
          end
        end
        
        COMPARE: begin
          cycle_count <= cycle_count + 8'd1;
          
          // Compare current elements
          case (index)
            3'd0: if (!(tup1_0 > tup2_0)) result <= 1'b0;
            3'd1: if (!(tup1_1 > tup2_1)) result <= 1'b0;
            3'd2: if (!(tup1_2 > tup2_2)) result <= 1'b0;
            3'd3: if (!(tup1_3 > tup2_3)) result <= 1'b0;
            3'd4: if (!(tup1_4 > tup2_4)) result <= 1'b0;
            3'd5: if (!(tup1_5 > tup2_5)) result <= 1'b0;
            3'd6: if (!(tup1_6 > tup2_6)) result <= 1'b0;
            3'd7: if (!(tup1_7 > tup2_7)) result <= 1'b0;
          endcase
          
          // Move to next element or finish
          if (index == len - 1 || cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
          end else begin
            index <= index + 3'd1;
          end
        end
        
        FINISH: begin
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule