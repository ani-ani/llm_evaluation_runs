module next_smallest (
  input clk,
  input rst_n,
  input start,
  input [7:0] valid_mask,
  input [7:0] data0, data1, data2, data3, data4, data5, data6, data7,
  output reg [7:0] second_smallest,
  output reg found,
  output reg done
);

localparam [3:0]
  IDLE     = 4'd0,
  COMPARE_0 = 4'd1,
  COMPARE_1 = 4'd2,
  COMPARE_2 = 4'd3,
  COMPARE_3 = 4'd4,
  COMPARE_4 = 4'd5,
  COMPARE_5 = 4'd6,
  COMPARE_6 = 4'd7,
  COMPARE_7 = 4'd8,
  FINISH   = 4'd9;

reg [3:0] state_reg, next_state;
reg signed [7:0] min_val, second_min;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state_reg <= IDLE;
    min_val <= 8'sh7F;
    second_min <= 8'sh7F;
    second_smallest <= 8'h00;
    found <= 0;
    done <= 0;
  end else begin
    done <= 0;
    case (state_reg)
      IDLE: begin
        if (start) begin
          min_val <= 8'sh7F;
          second_min <= 8'sh7F;
        end
      end
      COMPARE_0: if (valid_mask[0]) update_min_values($signed(data0));
      COMPARE_1: if (valid_mask[1]) update_min_values($signed(data1));
      COMPARE_2: if (valid_mask[2]) update_min_values($signed(data2));
      COMPARE_3: if (valid_mask[3]) update_min_values($signed(data3));
      COMPARE_4: if (valid_mask[4]) update_min_values($signed(data4));
      COMPARE_5: if (valid_mask[5]) update_min_values($signed(data5));
      COMPARE_6: if (valid_mask[6]) update_min_values($signed(data6));
      COMPARE_7: if (valid_mask[7]) update_min_values($signed(data7));
      FINISH: begin
        second_smallest <= second_min;
        found <= (second_min != 8'sh7F) && (min_val != second_min);
        done <= 1;
      end
    endcase
    state_reg <= next_state;
  end
end

task update_min_values(input signed [7:0] data);
  begin
    if (data < min_val) begin
      second_min <= min_val;
      min_val <= data;
    end else if ((data < second_min) && (data != min_val)) begin
      second_min <= data;
    end
  end
endtask

always_comb begin
  next_state = state_reg;
  case (state_reg)
    IDLE:     if (start) next_state = COMPARE_0;
    COMPARE_0: next_state = COMPARE_1;
    COMPARE_1: next_state = COMPARE_2;
    COMPARE_2: next_state = COMPARE_3;
    COMPARE_3: next_state = COMPARE_4;
    COMPARE_4: next_state = COMPARE_5;
    COMPARE_5: next_state = COMPARE_6;
    COMPARE_6: next_state = COMPARE_7;
    COMPARE_7: next_state = FINISH;
    FINISH:   next_state = IDLE;
    default:  next_state = IDLE;
  endcase
end

endmodule