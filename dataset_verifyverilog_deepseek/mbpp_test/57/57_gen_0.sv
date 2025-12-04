module form_largest_number #(parameter N=4) (
    input [N-1:0][3:0] digits,
    output logic [max_bits-1:0] max_num
);

localparam integer max_bits = (N * 3322 + 999) / 1000;

logic [3:0] sorted_digits [0:N-1];

always_comb begin
    for (int k=0; k<N; k++) sorted_digits[k] = digits[k];
    for (int i=0; i<N; i++) begin
        for (int j=0; j<N-1; j++) begin
            if (sorted_digits[j] < sorted_digits[j+1]) begin
                automatic logic [3:0] temp = sorted_digits[j];
                sorted_digits[j] = sorted_digits[j+1];
                sorted_digits[j+1] = temp;
            end
        end
    end
    max_num = 0;
    for (int i=0; i<N; i++) begin
        automatic integer exponent = N-1-i;
        automatic integer pow = 10**exponent;
        max_num += sorted_digits[i] * pow;
    end
end

endmodule