module pair_sum_counter(
  input  signed [7:0] element_0,
  input  signed [7:0] element_1,
  input  signed [7:0] element_2,
  input  signed [7:0] element_3,
  input  signed [7:0] element_4,
  input  signed [7:0] element_5,
  input  signed [7:0] element_6,
  input  signed [7:0] element_7,
  input  signed [7:0] target_sum,
  input        [2:0] valid_elements,
  output reg   [4:0] pair_count
);

  wire signed [7:0] e[7:0];

  assign e[0] = element_0;
  assign e[1] = element_1;
  assign e[2] = element_2;
  assign e[3] = element_3;
  assign e[4] = element_4;
  assign e[5] = element_5;
  assign e[6] = element_6;
  assign e[7] = element_7;

  integer i, j;

  always @* begin
    pair_count = 5'd0;
    for (i = 0; i < 7; i = i + 1) begin
      if (i < valid_elements) begin
        for (j = i + 1; j < 8; j = j + 1) begin
          if (j < valid_elements) begin
            if (e[i] + e[j] == target_sum) begin
              pair_count = pair_count + 5'd1;
            end
          end
        end
      end
    end
  end

endmodule