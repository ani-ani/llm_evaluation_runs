module sorted_list_checker(
  input  [3:0]  length,
  input  [63:0] lst,
  output reg    is_sorted
);

  // Extract 8-bit elements from packed list
  wire [7:0] e0 = lst[7:0];
  wire [7:0] e1 = lst[15:8];
  wire [7:0] e2 = lst[23:16];
  wire [7:0] e3 = lst[31:24];
  wire [7:0] e4 = lst[39:32];
  wire [7:0] e5 = lst[47:40];
  wire [7:0] e6 = lst[55:48];
  wire [7:0] e7 = lst[63:56];

  // Pairwise non-decreasing checks (only relevant up to length-1)
  wire pair01 = (e0 <= e1);
  wire pair12 = (e1 <= e2);
  wire pair23 = (e2 <= e3);
  wire pair34 = (e3 <= e4);
  wire pair45 = (e4 <= e5);
  wire pair56 = (e5 <= e6);
  wire pair67 = (e6 <= e7);

  // No three consecutive duplicates checks
  // Condition required: not (e_j == e_{j+1} && e_{j+1} == e_{j+2})
  wire no3_012 = !( (e0 == e1) && (e1 == e2) );
  wire no3_123 = !( (e1 == e2) && (e2 == e3) );
  wire no3_234 = !( (e2 == e3) && (e3 == e4) );
  wire no3_345 = !( (e3 == e4) && (e4 == e5) );
  wire no3_456 = !( (e4 == e5) && (e5 == e6) );
  wire no3_567 = !( (e5 == e6) && (e6 == e7) );

  always @* begin
    case (length)
      4'd0, 4'd1: begin
        is_sorted = 1'b1;
      end
      4'd2: begin
        is_sorted = pair01;
      end
      4'd3: begin
        is_sorted = pair01 && pair12 && no3_012;
      end
      4'd4: begin
        is_sorted = pair01 && pair12 && pair23 &&
                    no3_012 && no3_123;
      end
      4'd5: begin
        is_sorted = pair01 && pair12 && pair23 && pair34 &&
                    no3_012 && no3_123 && no3_234;
      end
      4'd6: begin
        is_sorted = pair01 && pair12 && pair23 && pair34 && pair45 &&
                    no3_012 && no3_123 && no3_234 && no3_345;
      end
      4'd7: begin
        is_sorted = pair01 && pair12 && pair23 && pair34 && pair45 && pair56 &&
                    no3_012 && no3_123 && no3_234 && no3_345 && no3_456;
      end
      4'd8: begin
        is_sorted = pair01 && pair12 && pair23 && pair34 && pair45 && pair56 && pair67 &&
                    no3_012 && no3_123 && no3_234 && no3_345 && no3_456 && no3_567;
      end
      default: begin
        // For lengths > 8 or invalid, treat as not sorted
        is_sorted = 1'b0;
      end
    endcase
  end

endmodule