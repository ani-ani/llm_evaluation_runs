module divisor_parity(input [15:0] n, output even_divisors);
reg even_divisors;
always @(*) begin
    reg [7:0] current_root;
    reg [7:0] temp;
    reg [31:0] temp_sq;
    current_root = 0;
    temp = current_root | (1 << 7);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 6);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 5);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 4);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 3);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 2);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 1);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    temp = current_root | (1 << 0);
    temp_sq = temp * temp;
    if (temp_sq <= n) current_root = temp;
    if (n == 0) begin
        even_divisors = 1;
    end else begin
        reg [31:0] square;
        square = current_root * current_root;
        even_divisors = (square == n) ? 0 : 1;
    end
end
endmodule