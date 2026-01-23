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

  // Parameters
  localparam [2:0] MAX_SIZE = 3'd8;
  
  // Internal state
  reg [2:0] state;
  reg [2:0] index;
  reg processing;
  reg intermediate_result;
  
  // State definitions
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] COMPARE = 2'd1;
  localparam [1:0] FINISH = 2'd2;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      index <= 3'd0;
      processing <= 1'b0;
      done <= 1'b0;
      result <= 1'b0;
      intermediate_result <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          index <= 3'd0;
          intermediate_result <= 1'b1;
          if (start) begin
            state <= COMPARE;
            processing <= 1'b1;
          end
        end
        
        COMPARE: begin
          if (index < len) begin
            // Compare current element based on index
            case (index)
              3'd0: begin
                if (!(tup1_0 > tup2_0)) intermediate_result <= 1'b0;
              end
              3'd1: begin
                if (!(tup1_1 > tup2_1)) intermediate_result <= 1'b0;
              end
              3'd2: begin
                if (!(tup1_2 > tup2_2)) intermediate_result <= 1'b0;
              end
              3'd3: begin
                if (!(tup1_3 > tup2_3)) intermediate_result <= 1'b0;
              end
              3'd4: begin
                if (!(tup1_4 > tup2_4)) intermediate_result <= 1'b0;
              end
              3'd5: begin
                if (!(tup1_5 > tup2_5)) intermediate_result <= 1'b0;
              end
              3'd6: begin
                if (!(tup1_6 > tup2_6)) intermediate_result <= 1'b0;
              end
              3'd7: begin
                if (!(tup1_7 > tup2_7)) intermediate_result <= 1'b0;
              end
              default: intermediate_result <= 1'b0;
            endcase
            index <= index + 3'd1;
          end else begin
            state <= FINISH;
          end
        end
        
        FINISH: begin
          result <= intermediate_result;
          done <= 1'b1;
          processing <= 1'b0;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule