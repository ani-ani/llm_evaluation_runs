module interesting_problemset(
  input [15:0] valid,
  input [63:0] problems,
  output logic result
);
  logic cond1, cond2;

  // Check for any valid problem that is all zeros
  always_comb begin
    cond1 = 1'b0;
    for (int i = 0; i < 16; i++) begin
      if (valid[i] && (problems[4*i +: 4] == 4'b0)) begin
        cond1 = 1'b1;
      end
    end
  end

  // Check for any two distinct valid problems that AND to zero
  always_comb begin
    cond2 = 1'b0;
    for (int i = 0; i < 16; i++) begin
      if (valid[i]) begin
        for (int j = i+1; j < 16; j++) begin
          if (valid[j] && ((problems[4*i +: 4] & problems[4*j +: 4]) == 4'b0)) begin
            cond2 = 1'b1;
          end
        end
      end
    end
  end

  assign result = cond1 || cond2;
endmodule