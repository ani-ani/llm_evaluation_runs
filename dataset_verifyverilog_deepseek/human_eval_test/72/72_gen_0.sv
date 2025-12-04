module will_it_fly (input reg [63:0] q_flat, input reg [3:0] length, input reg [10:0] w, output reg will_fly);
  logic [7:0] q [0:7];
  assign q[0] = q_flat[7:0];
  assign q[1] = q_flat[15:8];
  assign q[2] = q_flat[23:16];
  assign q[3] = q_flat[31:24];
  assign q[4] = q_flat[39:32];
  assign q[5] = q_flat[47:40];
  assign q[6] = q_flat[55:48];
  assign q[7] = q_flat[63:56];
  
  logic [3:0] j0, j1, j2, j3;
  assign j0 = length - 4'd1 - 4'd0;
  assign j1 = length - 4'd1 - 4'd1;
  assign j2 = length - 4'd1 - 4'd2;
  assign j3 = length - 4'd1 - 4'd3;
  
  logic en0, en1, en2, en3;
  assign en0 = (4'd0 * 4'd2) < (length - 4'd1);
  assign en1 = (4'd1 * 4'd2) < (length - 4'd1);
  assign en2 = (4'd2 * 4'd2) < (length - 4'd1);
  assign en3 = (4'd3 * 4'd2) < (length - 4'd1);
  
  logic fail0, fail1, fail2, fail3;
  assign fail0 = en0 && (q[0] != q[j0]);
  assign fail1 = en1 && (q[1] != q[j1]);
  assign fail2 = en2 && (q[2] != q[j2]);
  assign fail3 = en3 && (q[3] != q[j3]);
  
  logic palindrome_ok;
  assign palindrome_ok = (length <= 4'd1) ? 1'b1 : ~(fail0 || fail1 || fail2 || fail3);
  
  logic [10:0] sum;
  always_comb begin
    sum = 11'b0;
    for (int i = 0; i < 8; i++) begin
      if (i < length) begin
        sum = sum + q[i];
      end
    end
  end
  
  assign will_fly = palindrome_ok && (sum <= w);
endmodule