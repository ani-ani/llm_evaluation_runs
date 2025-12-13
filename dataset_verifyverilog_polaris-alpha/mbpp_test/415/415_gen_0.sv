module max_product_finder(
  input  signed [7:0] arr_input [7:0],
  output signed [7:0] num1,
  output signed [7:0] num2
);

  // Declare wires for all 28 pair products
  wire signed [15:0] prod_0_1 = arr_input[0] * arr_input[1];
  wire signed [15:0] prod_0_2 = arr_input[0] * arr_input[2];
  wire signed [15:0] prod_0_3 = arr_input[0] * arr_input[3];
  wire signed [15:0] prod_0_4 = arr_input[0] * arr_input[4];
  wire signed [15:0] prod_0_5 = arr_input[0] * arr_input[5];
  wire signed [15:0] prod_0_6 = arr_input[0] * arr_input[6];
  wire signed [15:0] prod_0_7 = arr_input[0] * arr_input[7];

  wire signed [15:0] prod_1_2 = arr_input[1] * arr_input[2];
  wire signed [15:0] prod_1_3 = arr_input[1] * arr_input[3];
  wire signed [15:0] prod_1_4 = arr_input[1] * arr_input[4];
  wire signed [15:0] prod_1_5 = arr_input[1] * arr_input[5];
  wire signed [15:0] prod_1_6 = arr_input[1] * arr_input[6];
  wire signed [15:0] prod_1_7 = arr_input[1] * arr_input[7];

  wire signed [15:0] prod_2_3 = arr_input[2] * arr_input[3];
  wire signed [15:0] prod_2_4 = arr_input[2] * arr_input[4];
  wire signed [15:0] prod_2_5 = arr_input[2] * arr_input[5];
  wire signed [15:0] prod_2_6 = arr_input[2] * arr_input[6];
  wire signed [15:0] prod_2_7 = arr_input[2] * arr_input[7];

  wire signed [15:0] prod_3_4 = arr_input[3] * arr_input[4];
  wire signed [15:0] prod_3_5 = arr_input[3] * arr_input[5];
  wire signed [15:0] prod_3_6 = arr_input[3] * arr_input[6];
  wire signed [15:0] prod_3_7 = arr_input[3] * arr_input[7];

  wire signed [15:0] prod_4_5 = arr_input[4] * arr_input[5];
  wire signed [15:0] prod_4_6 = arr_input[4] * arr_input[6];
  wire signed [15:0] prod_4_7 = arr_input[4] * arr_input[7];

  wire signed [15:0] prod_5_6 = arr_input[5] * arr_input[6];
  wire signed [15:0] prod_5_7 = arr_input[5] * arr_input[7];

  wire signed [15:0] prod_6_7 = arr_input[6] * arr_input[7];

  // Internal regs to track max product and corresponding pair
  reg signed [15:0] max_prod;
  reg signed [7:0] max_num1;
  reg signed [7:0] max_num2;

  // Combinational logic to find maximum product pair
  always @(*) begin
    // Initialize with the first pair (0,1)
    max_prod = prod_0_1;
    max_num1 = arr_input[0];
    max_num2 = arr_input[1];

    // For each subsequent pair, update only if strictly greater than current max_prod
    if (prod_0_2 > max_prod) begin max_prod = prod_0_2; max_num1 = arr_input[0]; max_num2 = arr_input[2]; end
    if (prod_0_3 > max_prod) begin max_prod = prod_0_3; max_num1 = arr_input[0]; max_num2 = arr_input[3]; end
    if (prod_0_4 > max_prod) begin max_prod = prod_0_4; max_num1 = arr_input[0]; max_num2 = arr_input[4]; end
    if (prod_0_5 > max_prod) begin max_prod = prod_0_5; max_num1 = arr_input[0]; max_num2 = arr_input[5]; end
    if (prod_0_6 > max_prod) begin max_prod = prod_0_6; max_num1 = arr_input[0]; max_num2 = arr_input[6]; end
    if (prod_0_7 > max_prod) begin max_prod = prod_0_7; max_num1 = arr_input[0]; max_num2 = arr_input[7]; end

    if (prod_1_2 > max_prod) begin max_prod = prod_1_2; max_num1 = arr_input[1]; max_num2 = arr_input[2]; end
    if (prod_1_3 > max_prod) begin max_prod = prod_1_3; max_num1 = arr_input[1]; max_num2 = arr_input[3]; end
    if (prod_1_4 > max_prod) begin max_prod = prod_1_4; max_num1 = arr_input[1]; max_num2 = arr_input[4]; end
    if (prod_1_5 > max_prod) begin max_prod = prod_1_5; max_num1 = arr_input[1]; max_num2 = arr_input[5]; end
    if (prod_1_6 > max_prod) begin max_prod = prod_1_6; max_num1 = arr_input[1]; max_num2 = arr_input[6]; end
    if (prod_1_7 > max_prod) begin max_prod = prod_1_7; max_num1 = arr_input[1]; max_num2 = arr_input[7]; end

    if (prod_2_3 > max_prod) begin max_prod = prod_2_3; max_num1 = arr_input[2]; max_num2 = arr_input[3]; end
    if (prod_2_4 > max_prod) begin max_prod = prod_2_4; max_num1 = arr_input[2]; max_num2 = arr_input[4]; end
    if (prod_2_5 > max_prod) begin max_prod = prod_2_5; max_num1 = arr_input[2]; max_num2 = arr_input[5]; end
    if (prod_2_6 > max_prod) begin max_prod = prod_2_6; max_num1 = arr_input[2]; max_num2 = arr_input[6]; end
    if (prod_2_7 > max_prod) begin max_prod = prod_2_7; max_num1 = arr_input[2]; max_num2 = arr_input[7]; end

    if (prod_3_4 > max_prod) begin max_prod = prod_3_4; max_num1 = arr_input[3]; max_num2 = arr_input[4]; end
    if (prod_3_5 > max_prod) begin max_prod = prod_3_5; max_num1 = arr_input[3]; max_num2 = arr_input[5]; end
    if (prod_3_6 > max_prod) begin max_prod = prod_3_6; max_num1 = arr_input[3]; max_num2 = arr_input[6]; end
    if (prod_3_7 > max_prod) begin max_prod = prod_3_7; max_num1 = arr_input[3]; max_num2 = arr_input[7]; end

    if (prod_4_5 > max_prod) begin max_prod = prod_4_5; max_num1 = arr_input[4]; max_num2 = arr_input[5]; end
    if (prod_4_6 > max_prod) begin max_prod = prod_4_6; max_num1 = arr_input[4]; max_num2 = arr_input[6]; end
    if (prod_4_7 > max_prod) begin max_prod = prod_4_7; max_num1 = arr_input[4]; max_num2 = arr_input[7]; end

    if (prod_5_6 > max_prod) begin max_prod = prod_5_6; max_num1 = arr_input[5]; max_num2 = arr_input[6]; end
    if (prod_5_7 > max_prod) begin max_prod = prod_5_7; max_num1 = arr_input[5]; max_num2 = arr_input[7]; end

    if (prod_6_7 > max_prod) begin max_prod = prod_6_7; max_num1 = arr_input[6]; max_num2 = arr_input[7]; end
  end

  assign num1 = max_num1;
  assign num2 = max_num2;

endmodule