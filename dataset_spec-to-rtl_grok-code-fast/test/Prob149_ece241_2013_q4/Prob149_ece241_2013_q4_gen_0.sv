module TopModule(
  input reg clk,
  input reg reset,
  input reg [2:0] s,
  output fr2,
  output fr1,
  output fr0,
  output dfr
);

  reg [2:0] prev_s;
  wire [2:0] fr;

  assign {fr2, fr1, fr0} = fr;

  always @(posedge clk)
  begin
    if (reset) begin
      prev_s <= 3'b000;
    end else begin
      prev_s <= s;
    end
  end

  always @* begin
    integer cl, pl;
    cl = (s == 3'b111) ? 3 : (s == 3'b011) ? 2 : (s == 3'b001) ? 1 : 0;
    pl = (prev_s == 3'b111) ? 3 : (prev_s == 3'b011) ? 2 : (prev_s == 3'b001) ? 1 : 0;
    dfr = (pl < cl);
    case (cl)
      0: fr = 3'b111;
      1: fr = 3'b011;
      2: fr = 3'b001;
      3: fr = 3'b000;
      default: fr = 3'b111; // default to below
    endcase
  end

endmodule