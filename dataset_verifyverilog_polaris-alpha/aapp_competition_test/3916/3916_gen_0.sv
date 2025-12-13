module path_sum_optimizer(
  input  [3:0] k [0:7],       // Up to 8 fragments (4 bits each, 0-15)
  input  [2:0] num_fragments, // Actual fragment count (0-8)
  output [6:0] min_sum
);

  // Precomputed prime exponents for k! where k = 0..15
  // Primes: 2,3,5,7,11,13
  // exponents_2_table[k], exponents_3_table[k], ... etc.
  function automatic [5:0] exp2 (input [3:0] x);
    case (x)
      4'd0,4'd1: exp2 = 6'd0;
      4'd2: exp2 = 6'd1;
      4'd3: exp2 = 6'd1;
      4'd4: exp2 = 6'd3;
      4'd5: exp2 = 6'd3;
      4'd6: exp2 = 6'd4;
      4'd7: exp2 = 6'd4;
      4'd8: exp2 = 6'd7;
      4'd9: exp2 = 6'd7;
      4'd10: exp2 = 6'd8;
      4'd11: exp2 = 6'd8;
      4'd12: exp2 = 6'd10;
      4'd13: exp2 = 6'd10;
      4'd14: exp2 = 6'd11;
      4'd15: exp2 = 6'd11;
      default: exp2 = 6'd0;
    endcase
  endfunction

  function automatic [5:0] exp3 (input [3:0] x);
    case (x)
      4'd0,4'd1,4'd2: exp3 = 6'd0;
      4'd3: exp3 = 6'd1;
      4'd4: exp3 = 6'd1;
      4'd5: exp3 = 6'd1;
      4'd6: exp3 = 6'd2;
      4'd7: exp3 = 6'd2;
      4'd8: exp3 = 6'd2;
      4'd9: exp3 = 6'd4;
      4'd10: exp3 = 6'd4;
      4'd11: exp3 = 6'd4;
      4'd12: exp3 = 6'd5;
      4'd13: exp3 = 6'd5;
      4'd14: exp3 = 6'd5;
      4'd15: exp3 = 6'd6;
      default: exp3 = 6'd0;
    endcase
  endfunction

  function automatic [5:0] exp5 (input [3:0] x);
    case (x)
      4'd0,4'd1,4'd2,4'd3,4'd4: exp5 = 6'd0;
      4'd5: exp5 = 6'd1;
      4'd6: exp5 = 6'd1;
      4'd7: exp5 = 6'd1;
      4'd8: exp5 = 6'd1;
      4'd9: exp5 = 6'd1;
      4'd10: exp5 = 6'd2;
      4'd11: exp5 = 6'd2;
      4'd12: exp5 = 6'd2;
      4'd13: exp5 = 6'd2;
      4'd14: exp5 = 6'd2;
      4'd15: exp5 = 6'd3;
      default: exp5 = 6'd0;
    endcase
  endfunction

  function automatic [5:0] exp7 (input [3:0] x);
    case (x)
      4'd0,4'd1,4'd2,4'd3,4'd4,4'd5,4'd6: exp7 = 6'd0;
      4'd7: exp7 = 6'd1;
      4'd8: exp7 = 6'd1;
      4'd9: exp7 = 6'd1;
      4'd10: exp7 = 6'd1;
      4'd11: exp7 = 6'd1;
      4'd12: exp7 = 6'd1;
      4'd13: exp7 = 6'd1;
      4'd14: exp7 = 6'd2;
      4'd15: exp7 = 6'd2;
      default: exp7 = 6'd0;
    endcase
  endfunction

  function automatic [5:0] exp11 (input [3:0] x);
    case (x)
      4'd0: exp11 = 6'd0;
      4'd1: exp11 = 6'd0;
      4'd2: exp11 = 6'd0;
      4'd3: exp11 = 6'd0;
      4'd4: exp11 = 6'd0;
      4'd5: exp11 = 6'd0;
      4'd6: exp11 = 6'd0;
      4'd7: exp11 = 6'd0;
      4'd8: exp11 = 6'd0;
      4'd9: exp11 = 6'd0;
      4'd10: exp11 = 6'd0;
      4'd11: exp11 = 6'd1;
      4'd12: exp11 = 6'd1;
      4'd13: exp11 = 6'd1;
      4'd14: exp11 = 6'd1;
      4'd15: exp11 = 6'd1;
      default: exp11 = 6'd0;
    endcase
  endfunction

  function automatic [5:0] exp13 (input [3:0] x);
    case (x)
      4'd0: exp13 = 6'd0;
      4'd1: exp13 = 6'd0;
      4'd2: exp13 = 6'd0;
      4'd3: exp13 = 6'd0;
      4'd4: exp13 = 6'd0;
      4'd5: exp13 = 6'd0;
      4'd6: exp13 = 6'd0;
      4'd7: exp13 = 6'd0;
      4'd8: exp13 = 6'd0;
      4'd9: exp13 = 6'd0;
      4'd10: exp13 = 6'd0;
      4'd11: exp13 = 6'd0;
      4'd12: exp13 = 6'd0;
      4'd13: exp13 = 6'd1;
      4'd14: exp13 = 6'd1;
      4'd15: exp13 = 6'd1;
      default: exp13 = 6'd0;
    endcase
  endfunction

  // Sum exponents across active fragments (0 .. num_fragments-1)
  integer i;
  reg [5:0] sum2, sum3, sum5, sum7, sum11, sum13;
  reg [6:0] total_sum;

  always @* begin
    sum2  = 6'd0;
    sum3  = 6'd0;
    sum5  = 6'd0;
    sum7  = 6'd0;
    sum11 = 6'd0;
    sum13 = 6'd0;

    for (i = 0; i < 8; i = i + 1) begin
      if (i < num_fragments) begin
        sum2  = sum2  + exp2 (k[i]);
        sum3  = sum3  + exp3 (k[i]);
        sum5  = sum5  + exp5 (k[i]);
        sum7  = sum7  + exp7 (k[i]);
        sum11 = sum11 + exp11(k[i]);
        sum13 = sum13 + exp13(k[i]);
      end
    end

    // Minimal total path length using majority-like metric per prime:
    // For each prime, cost_p = min(S_p, N - S_p) where S_p is total exponent,
    // and N is num_fragments (acts as reference/"level" count).
    // Then min_sum = sum over all primes of cost_p.

    // Extend num_fragments to 6 bits for arithmetic with exponents
    // (max exponent per prime <= 47 < 64).
    reg [5:0] N;
    reg [5:0] c2, c3, c5, c7, c11p, c13p;

    N = {3'd0, num_fragments};

    c2   = (sum2  <= N ? sum2  : (N - (sum2  - N)) );
    c3   = (sum3  <= N ? sum3  : (N - (sum3  - N)) );
    c5   = (sum5  <= N ? sum5  : (N - (sum5  - N)) );
    c7   = (sum7  <= N ? sum7  : (N - (sum7  - N)) );
    c11p = (sum11 <= N ? sum11 : (N - (sum11 - N)) );
    c13p = (sum13 <= N ? sum13 : (N - (sum13 - N)) );

    total_sum = c2 + c3 + c5 + c7 + c11p + c13p;
  end

  assign min_sum = total_sum;

endmodule