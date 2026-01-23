module cable_car_planner(
  input [3:0] n,
  input [2:0] k,
  output valid,
  output [3:0] ms_0, me_0,
  output [3:0] ms_1, me_1,
  output [3:0] ms_2, me_2,
  output [3:0] ms_3, me_3,
  output [3:0] vs_0, ve_0,
  output [3:0] vs_1, ve_1,
  output [3:0] vs_2, ve_2,
  output [3:0] vs_3, ve_3
);

  wire [3:0] ms [0:3];
  wire [3:0] me [0:3];
  wire [3:0] vs [0:3];
  wire [3:0] ve [0:3];

  assign valid = (2*k <= n - 1) ? 1'b1 : 1'b0;

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_cable_cars
      assign ms[i] = (i < k) ? (2*i + 1) : 4'b0;
      assign me[i] = (i < k) ? (2*i + 2) : 4'b0;
      assign vs[i] = (i < k) ? (2*i + 1) : 4'b0;
      assign ve[i] = (i < k) ? (n - i) : 4'b0;
    end
  endgenerate

  assign ms_0 = ms[0];
  assign me_0 = me[0];
  assign ms_1 = ms[1];
  assign me_1 = me[1];
  assign ms_2 = ms[2];
  assign me_2 = me[2];
  assign ms_3 = ms[3];
  assign me_3 = me[3];

  assign vs_0 = vs[0];
  assign ve_0 = ve[0];
  assign vs_1 = vs[1];
  assign ve_1 = ve[1];
  assign vs_2 = vs[2];
  assign ve_2 = ve[2];
  assign vs_3 = vs[3];
  assign ve_3 = ve[3];

endmodule