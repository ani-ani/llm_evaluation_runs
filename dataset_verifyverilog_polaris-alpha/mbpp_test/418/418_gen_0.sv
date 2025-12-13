module max_length_element(
  input  [7:0] list0_0,
  input  [7:0] list0_1,
  input  [7:0] list0_2,
  input  [7:0] list0_3,
  input  [3:0] valid0,
  input  [7:0] list1_0,
  input  [7:0] list1_1,
  input  [7:0] list1_2,
  input  [7:0] list1_3,
  input  [3:0] valid1,
  input  [7:0] list2_0,
  input  [7:0] list2_1,
  input  [7:0] list2_2,
  input  [7:0] list2_3,
  input  [3:0] valid2,
  input  [7:0] list3_0,
  input  [7:0] list3_1,
  input  [7:0] list3_2,
  input  [7:0] list3_3,
  input  [3:0] valid3,
  output [7:0] max_element,
  output [1:0] max_list_idx,
  output [1:0] max_pos_idx,
  output       any_valid
);

  // Compute lengths (population count of valid masks)
  wire [2:0] len0 = valid0[0] + valid0[1] + valid0[2] + valid0[3];
  wire [2:0] len1 = valid1[0] + valid1[1] + valid1[2] + valid1[3];
  wire [2:0] len2 = valid2[0] + valid2[1] + valid2[2] + valid2[3];
  wire [2:0] len3 = valid3[0] + valid3[1] + valid3[2] + valid3[3];

  // Track max length and corresponding list index (tie-breaker: lowest index)
  reg [2:0] max_len;
  reg [1:0] sel_list;

  always @* begin
    max_len  = len0;
    sel_list = 2'd0;

    if (len1 > max_len) begin
      max_len  = len1;
      sel_list = 2'd1;
    end
    if (len2 > max_len) begin
      max_len  = len2;
      sel_list = 2'd2;
    end
    if (len3 > max_len) begin
      max_len  = len3;
      sel_list = 2'd3;
    end
  end

  // any_valid indicates presence of at least one valid element overall
  assign any_valid = (len0 != 3'd0) | (len1 != 3'd0) | (len2 != 3'd0) | (len3 != 3'd0);

  // For the selected list, choose the maximum element among valid entries.
  // If no valid entries in the chosen list, outputs will default to 0.

  reg [7:0] max_elem_r;
  reg [1:0] max_pos_r;

  always @* begin
    max_elem_r = 8'd0;
    max_pos_r  = 2'd0;

    case (sel_list)
      2'd0: begin
        // Initialize to first valid element if any
        if (valid0[0]) begin
          max_elem_r = list0_0;
          max_pos_r  = 2'd0;
        end else if (valid0[1]) begin
          max_elem_r = list0_1;
          max_pos_r  = 2'd1;
        end else if (valid0[2]) begin
          max_elem_r = list0_2;
          max_pos_r  = 2'd2;
        end else if (valid0[3]) begin
          max_elem_r = list0_3;
          max_pos_r  = 2'd3;
        end

        // Compare remaining valid entries
        if (valid0[1] && (!valid0[0] || list0_1 > max_elem_r)) begin
          max_elem_r = list0_1;
          max_pos_r  = 2'd1;
        end
        if (valid0[2] && (!valid0[0] && !valid0[1] || list0_2 > max_elem_r)) begin
          max_elem_r = list0_2;
          max_pos_r  = 2'd2;
        end
        if (valid0[3] && (!valid0[0] && !valid0[1] && !valid0[2] || list0_3 > max_elem_r)) begin
          max_elem_r = list0_3;
          max_pos_r  = 2'd3;
        end
      end

      2'd1: begin
        if (valid1[0]) begin
          max_elem_r = list1_0;
          max_pos_r  = 2'd0;
        end else if (valid1[1]) begin
          max_elem_r = list1_1;
          max_pos_r  = 2'd1;
        end else if (valid1[2]) begin
          max_elem_r = list1_2;
          max_pos_r  = 2'd2;
        end else if (valid1[3]) begin
          max_elem_r = list1_3;
          max_pos_r  = 2'd3;
        end

        if (valid1[1] && (!valid1[0] || list1_1 > max_elem_r)) begin
          max_elem_r = list1_1;
          max_pos_r  = 2'd1;
        end
        if (valid1[2] && (!valid1[0] && !valid1[1] || list1_2 > max_elem_r)) begin
          max_elem_r = list1_2;
          max_pos_r  = 2'd2;
        end
        if (valid1[3] && (!valid1[0] && !valid1[1] && !valid1[2] || list1_3 > max_elem_r)) begin
          max_elem_r = list1_3;
          max_pos_r  = 2'd3;
        end
      end

      2'd2: begin
        if (valid2[0]) begin
          max_elem_r = list2_0;
          max_pos_r  = 2'd0;
        end else if (valid2[1]) begin
          max_elem_r = list2_1;
          max_pos_r  = 2'd1;
        end else if (valid2[2]) begin
          max_elem_r = list2_2;
          max_pos_r  = 2'd2;
        end else if (valid2[3]) begin
          max_elem_r = list2_3;
          max_pos_r  = 2'd3;
        end

        if (valid2[1] && (!valid2[0] || list2_1 > max_elem_r)) begin
          max_elem_r = list2_1;
          max_pos_r  = 2'd1;
        end
        if (valid2[2] && (!valid2[0] && !valid2[1] || list2_2 > max_elem_r)) begin
          max_elem_r = list2_2;
          max_pos_r  = 2'd2;
        end
        if (valid2[3] && (!valid2[0] && !valid2[1] && !valid2[2] || list2_3 > max_elem_r)) begin
          max_elem_r = list2_3;
          max_pos_r  = 2'd3;
        end
      end

      2'd3: begin
        if (valid3[0]) begin
          max_elem_r = list3_0;
          max_pos_r  = 2'd0;
        end else if (valid3[1]) begin
          max_elem_r = list3_1;
          max_pos_r  = 2'd1;
        end else if (valid3[2]) begin
          max_elem_r = list3_2;
          max_pos_r  = 2'd2;
        end else if (valid3[3]) begin
          max_elem_r = list3_3;
          max_pos_r  = 2'd3;
        end

        if (valid3[1] && (!valid3[0] || list3_1 > max_elem_r)) begin
          max_elem_r = list3_1;
          max_pos_r  = 2'd1;
        end
        if (valid3[2] && (!valid3[0] && !valid3[1] || list3_2 > max_elem_r)) begin
          max_elem_r = list3_2;
          max_pos_r  = 2'd2;
        end
        if (valid3[3] && (!valid3[0] && !valid3[1] && !valid3[2] || list3_3 > max_elem_r)) begin
          max_elem_r = list3_3;
          max_pos_r  = 2'd3;
        end
      end

      default: begin
        max_elem_r = 8'd0;
        max_pos_r  = 2'd0;
      end
    endcase
  end

  assign max_element  = max_elem_r;
  assign max_list_idx = sel_list;
  assign max_pos_idx  = max_pos_r;

endmodule