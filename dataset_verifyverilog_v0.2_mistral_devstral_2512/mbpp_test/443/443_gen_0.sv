module largest_neg (
  input [7:0] list1_0,
  input [7:0] list1_1,
  input [7:0] list1_2,
  input [7:0] list1_3,
  input [7:0] list1_4,
  input [7:0] list1_5,
  input [7:0] list1_6,
  input [7:0] list1_7,
  input [2:0] valid_count,
  output reg [7:0] result,
  output reg found
);

  reg [7:0] max_neg;
  integer i;

  always @* begin
    found = 1'b0;
    result = 8'b0;
    max_neg = 8'b0;

    for (i = 0; i < valid_count; i = i + 1) begin
      case (i)
        0: begin
          if (list1_0[7]) begin
            if (!found || list1_0 > max_neg) begin
              max_neg = list1_0;
              found = 1'b1;
            end
          end
        end
        1: begin
          if (list1_1[7]) begin
            if (!found || list1_1 > max_neg) begin
              max_neg = list1_1;
              found = 1'b1;
            end
          end
        end
        2: begin
          if (list1_2[7]) begin
            if (!found || list1_2 > max_neg) begin
              max_neg = list1_2;
              found = 1'b1;
            end
          end
        end
        3: begin
          if (list1_3[7]) begin
            if (!found || list1_3 > max_neg) begin
              max_neg = list1_3;
              found = 1'b1;
            end
          end
        end
        4: begin
          if (list1_4[7]) begin
            if (!found || list1_4 > max_neg) begin
              max_neg = list1_4;
              found = 1'b1;
            end
          end
        end
        5: begin
          if (list1_5[7]) begin
            if (!found || list1_5 > max_neg) begin
              max_neg = list1_5;
              found = 1'b1;
            end
          end
        end
        6: begin
          if (list1_6[7]) begin
            if (!found || list1_6 > max_neg) begin
              max_neg = list1_6;
              found = 1'b1;
            end
          end
        end
        7: begin
          if (list1_7[7]) begin
            if (!found || list1_7 > max_neg) begin
              max_neg = list1_7;
              found = 1'b1;
            end
          end
        end
      endcase
    end

    result = max_neg;
  end

endmodule