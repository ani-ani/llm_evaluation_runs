module element_counter (
  input [7:0] tuple [7:0],
  input [7:0] list [3:0],
  output logic [3:0] count
);
  
  logic [7:0] matches;
  
  always_comb begin
    matches = 8'b0;
    for (int i = 0; i < 8; i++) begin
      for (int j = 0; j < 4; j++) begin
        if (tuple[i] == list[j]) begin
          matches[i] = 1'b1;
          break;
        end
      end
    end
    count = matches[0] + matches[1] + matches[2] + matches[3] 
          + matches[4] + matches[5] + matches[6] + matches[7];
  end
  
endmodule