module pair_sum_counter(
  input [7:0] element_0,
  input [7:0] element_1,
  input [7:0] element_2,
  input [7:0] element_3,
  input [7:0] element_4,
  input [7:0] element_5,
  input [7:0] element_6,
  input [7:0] element_7,
  input [7:0] target_sum,
  input [2:0] valid_elements,
  output reg [4:0] pair_count
);

  logic [7:0] elements [0:7];
  integer i, j;

  always_comb begin
    elements[0] = element_0;
    elements[1] = element_1;
    elements[2] = element_2;
    elements[3] = element_3;
    elements[4] = element_4;
    elements[5] = element_5;
    elements[6] = element_6;
    elements[7] = element_7;
    pair_count = 5'd0;
    for (i = 0; i < 7; i = i + 1) begin
      if (i < valid_elements) begin
        for (j = i + 1; j < 8; j = j + 1) begin
          if (j < valid_elements) begin
            if ($signed(elements[i]) + $signed(elements[j]) == $signed(target_sum)) begin
              pair_count = pair_count + 1'b1;
            end
          end
        end
      end
    end
  end

endmodule