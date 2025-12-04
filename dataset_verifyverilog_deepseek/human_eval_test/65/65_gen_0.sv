module circular_shift_digits (
  input [15:0] num,
  input [3:0] shift,
  output [15:0] shifted_digits
);
  logic [3:0] dig0, dig1, dig2, dig3;
  logic [3:0] num_digits;
  logic [3:0][3:0] sig_in, output_digits;

  assign dig0 = num[3:0];
  assign dig1 = num[7:4];
  assign dig2 = num[11:8];
  assign dig3 = num[15:12];
  assign sig_in[0] = dig0;
  assign sig_in[1] = dig1;
  assign sig_in[2] = dig2;
  assign sig_in[3] = dig3;

  always_comb begin
    if (num >= 1000) num_digits = 4;
    else if (num >= 100) num_digits = 3;
    else if (num >= 10) num_digits = 2;
    else num_digits = 1;
  end

  always_comb begin
    output_digits = sig_in;
    if (shift >= num_digits) begin
      for (int i=0; i < num_digits; i++) begin
        output_digits[i] = sig_in[num_digits-1 - i];
      end
    end else begin
      case (num_digits)
        1: output_digits[0] = sig_in[0];
        2: case (shift)
             1: {output_digits[0], output_digits[1]} = {sig_in[1], sig_in[0]};
             default: ;
           endcase
        3: case (shift)
             1: {output_digits[0], output_digits[1], output_digits[2]} = {sig_in[2], sig_in[0], sig_in[1]};
             2: {output_digits[0], output_digits[1], output_digits[2]} = {sig_in[1], sig_in[2], sig_in[0]};
             default: ;
           endcase
        4: case (shift)
             1: {output_digits[0], output_digits[1], output_digits[2], output_digits[3]} = {sig_in[3], sig_in[0], sig_in[1], sig_in[2]};
             2: {output_digits[0], output_digits[1], output_digits[2], output_digits[3]} = {sig_in[2], sig_in[3], sig_in[0], sig_in[1]};
             3: {output_digits[0], output_digits[1], output_digits[2], output_digits[3]} = {sig_in[1], sig_in[2], sig_in[3], sig_in[0]};
             default: ;
           endcase
      endcase
    end
  end

  assign shifted_digits = {output_digits[3], output_digits[2], output_digits[1], output_digits[0]};
endmodule