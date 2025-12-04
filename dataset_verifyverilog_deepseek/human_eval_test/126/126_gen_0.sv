module sorted_list_checker (
  input [3:0] length,
  input [63:0] lst,
  output reg is_sorted
);
  
  logic [7:0] els [0:7];
  
  generate
    for (genvar i = 0; i < 8; i++) begin
      assign els[i] = lst[i*8 +: 8];
    end
  endgenerate
  
  logic all_ordered, no_three_dupes;
  
  always_comb begin
    all_ordered = 1'b1;
    if (length >= 2) begin
      for (int i = 0; i < length-1; i++) begin
        all_ordered &= (els[i] <= els[i+1]);
      end
    end
  end
  
  always_comb begin
    no_three_dupes = 1'b1;
    if (length >= 3) begin
      for (int j = 0; j < length-2; j++) begin
        no_three_dupes &= !(els[j] == els[j+1] && els[j+1] == els[j+2]);
      end
    end
  end
  
  always_comb begin
    is_sorted = (length <= 1) || (all_ordered && no_three_dupes);
  end
  
endmodule