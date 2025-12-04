module circular_shift_digits(
  input logic [15:0] num,
  input logic [3:0] shift,
  output logic [15:0] shifted_digits
);

  // Extract decimal digits
  logic [3:0] d [4]; // LSD-first: d[0]=units, d[1]=tens, d[2]=hundreds, d[3]=thousands
  logic [3:0] nd [4]; // transformed digits
  logic [3:0] num_digits;

  always_comb begin
    d[0] = num % 10;
    d[1] = (num / 10) % 10;
    d[2] = (num / 100) % 10;
    d[3] = (num / 1000) % 10;
  end

  // Determine number of significant digits
  always_comb begin
    if (num >= 16'd1000) num_digits = 4;
    else if (num >= 16'd100) num_digits = 3;
    else if (num >= 16'd10) num_digits = 2;
    else num_digits = 1;
  end

  // Transform digits
  always_comb begin
    // initial copy
    for (int i=0; i<4; i++) nd[i] = d[i];

    if (shift >= num_digits) begin
      // reverse the first num_digits digits
      for (int i=0; i<num_digits; i++) begin
        nd[i] = d[num_digits - 1 - i];
      end
    end else begin
      // circular right shift of significant digits
      for (int i=0; i<num_digits; i++) begin
        int idx = i - shift;
        if (idx < 0) idx = idx + num_digits;
        nd[i] = d[idx];
      end
    end
  end

  // Pack the four 4‑bit digits into the output
  assign shifted_digits = {nd[3], nd[2], nd[1], nd[0]};

endmodule