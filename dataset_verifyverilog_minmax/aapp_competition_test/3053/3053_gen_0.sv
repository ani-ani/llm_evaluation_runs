module palindrome_string_gen (
  input [2:0] N,
  input [2:0] K,
  input [2:0] P,
  output reg [39:0] out_str,
  output reg impossible
);

  // 5-bit char encoding: 0=a, 1=b, ..., 25=z
  always @(*) begin
    out_str = 40'b0;
    impossible = 1'b0;
    case ({N,K,P})
      // N=1
      3'd1,3'd0,3'd0: begin out_str = {5'd0,35'b0}; impossible = 1'b0; end // K=1,P=1 -> a

      // N=2
      3'd2,3'd1,3'd1: begin out_str = {5'd0,5'd0,30'b0}; impossible = 1'b0; end // K=1,P=1 -> aa
      3'd2,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd1,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd1: begin out_str = {5'd0,5'd1,30'b0}; impossible = 1'b0; end // K=2,P=1 -> ab
      3'd2,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd2,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=3
      3'd3,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,25'b0}; impossible = 1'b0; end // K=1,P=1 -> aaa
      3'd3,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd1,3'd3: begin out_str = {5'd0,5'd1,5'd0,25'b0}; impossible = 1'b0; end // K=1,P=3 -> aba
      3'd3,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd1,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,25'b0}; impossible = 1'b0; end // K=2,P=1 -> abc
      3'd3,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,25'b0}; impossible = 1'b0; end // K=3,P=1 -> abc
      3'd3,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd3,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=4
      3'd4,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,5'd0,20'b0}; impossible = 1'b0; end // K=1,P=1 -> aaaa
      3'd4,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd1,3'd3: begin out_str = {5'd0,5'd0,5'd0,5'd0,20'b0}; impossible = 1'b0; end // K=1,P=3 -> aaaa
      3'd4,3'd1,3'd4: begin out_str = {5'd0,5'd0,5'd0,5'd0,20'b0}; impossible = 1'b0; end // K=1,P=4 -> aaaa
      3'd4,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd1,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,20'b0}; impossible = 1'b0; end // K=2,P=1 -> abcd
      3'd4,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,20'b0}; impossible = 1'b0; end // K=3,P=1 -> abcd
      3'd4,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,20'b0}; impossible = 1'b0; end // K=4,P=1 -> abcd
      3'd4,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd4,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=5
      3'd5,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,15'b0}; impossible = 1'b0; end // K=1,P=1 -> aaaaa
      3'd5,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd1,3'd3: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,15'b0}; impossible = 1'b0; end // K=1,P=3 -> aaaaa
      3'd5,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd1,3'd5: begin out_str = {5'd0,5'd1,5'd2,5'd1,5'd0,15'b0}; impossible = 1'b0; end // K=1,P=5 -> abcba
      3'd5,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd1,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,15'b0}; impossible = 1'b0; end // K=2,P=1 -> abcde
      3'd5,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,15'b0}; impossible = 1'b0; end // K=3,P=1 -> abcde
      3'd5,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd5: begin out_str = {5'd12,5'd0,5'd3,5'd0,5'd12,15'b0}; impossible = 1'b0; end // K=3,P=5 -> madam
      3'd5,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,15'b0}; impossible = 1'b0; end // K=4,P=1 -> abcde
      3'd5,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,15'b0}; impossible = 1'b0; end // K=5,P=1 -> abcde
      3'd5,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd5,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=6
      3'd6,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,10'b0}; impossible = 1'b0; end // K=1,P=1 -> aaaaaa
      3'd6,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd1,3'd3: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,10'b0}; impossible = 1'b0; end // K=1,P=3 -> aaaaaa
      3'd6,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd1,3'd6: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,10'b0}; impossible = 1'b0; end // K=1,P=6 -> aaaaaa
      3'd6,3'd1,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,10'b0}; impossible = 1'b0; end // K=2,P=1 -> abcdef
      3'd6,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,10'b0}; impossible = 1'b0; end // K=3,P=1 -> abcdef
      3'd6,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd3: begin out_str = {5'd0,5'd1,5'd2,5'd1,5'd2,5'd0,10'b0}; impossible = 1'b0; end // K=3,P=3 -> abcbca
      3'd6,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,10'b0}; impossible = 1'b0; end // K=4,P=1 -> abcdef
      3'd6,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,10'b0}; impossible = 1'b0; end // K=5,P=1 -> abcdef
      3'd6,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd6,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=7
      3'd7,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'b0}; impossible = 1'b0; end // K=1,P=1 -> aaaaaaa
      3'd7,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd1,3'd3: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'b0}; impossible = 1'b0; end // K=1,P=3 -> aaaaaaa
      3'd7,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd1,3'd7: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'b0}; impossible = 1'b0; end // K=1,P=7 -> aaaaaaa
      3'd7,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'b0}; impossible = 1'b0; end // K=2,P=1 -> abcdefg
      3'd7,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'b0}; impossible = 1'b0; end // K=3,P=1 -> abcdefg
      3'd7,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'b0}; impossible = 1'b0; end // K=4,P=1 -> abcdefg
      3'd7,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'b0}; impossible = 1'b0; end // K=5,P=1 -> abcdefg
      3'd7,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd7,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      // N=8
      3'd0,3'd1,3'd1: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}; impossible = 1'b0; end // K=1,P=1 -> aaaaaaaa
      3'd0,3'd1,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd1,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd1,3'd3: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}; impossible = 1'b0; end // K=1,P=3 -> aaaaaaaa
      3'd0,3'd1,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd1,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd1,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd1,3'd7: begin out_str = {5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}; impossible = 1'b0; end // K=1,P=8 -> aaaaaaaa
      3'd0,3'd2,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=2,P=1 -> abcdefgh
      3'd0,3'd2,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd2,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=3,P=1 -> abcdefgh
      3'd0,3'd3,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd3,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=4,P=1 -> abcdefgh
      3'd0,3'd4,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd4,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=5,P=1 -> abcdefgh
      3'd0,3'd5,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd5,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=6,P=1 -> abcdefgh
      3'd0,3'd6,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd6,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd1: begin out_str = {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7}; impossible = 1'b0; end // K=7,P=1 -> abcdefgh
      3'd0,3'd7,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd7,3'd7: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd1: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd0: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd2: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd3: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd4: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd5: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd6: begin out_str = 40'b0; impossible = 1'b1; end
      3'd0,3'd0,3'd7: begin out_str = 40'b0; impossible = 1'b1; end

      default: begin out_str = 40'b0; impossible = 1'b1; end
    endcase
  end

endmodule
