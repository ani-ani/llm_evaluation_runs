module evolution_plans_counter (
  input [1:0] n,
  input [2:0] m,
  input [1:0] gym0_count,
  input [1:0] gym1_count,
  input [1:0] gym0_types [0:3],
  input [1:0] gym1_types [0:3],
  output logic [6:0] count
);

  // Enable signals for each type (1-4)
  wire en1 = (7'd1 <= m);
  wire en2 = (7'd2 <= m);
  wire en3 = (7'd3 <= m);
  wire en4 = (7'd4 <= m);

  // Compute gym counts per type
  wire [1:0] count0_t1 = (en1) ?
    ((gym0_count >= 1) && (gym0_types[0] == 2'd1)) +
    ((gym0_count >= 2) && (gym0_types[1] == 2'd1)) +
    ((gym0_count >= 3) && (gym0_types[2] == 2'd1)) : 2'd0;

  wire [1:0] count1_t1 = (en1) ?
    ((gym1_count >= 1) && (gym1_types[0] == 2'd1)) +
    ((gym1_count >= 2) && (gym1_types[1] == 2'd1)) +
    ((gym1_count >= 3) && (gym1_types[2] == 2'd1)) : 2'd0;

  wire [1:0] count0_t2 = (en2) ?
    ((gym0_count >= 1) && (gym0_types[0] == 2'd2)) +
    ((gym0_count >= 2) && (gym0_types[1] == 2'd2)) +
    ((gym0_count >= 3) && (gym0_types[2] == 2'd2)) : 2'd0;

  wire [1:0] count1_t2 = (en2) ?
    ((gym1_count >= 1) && (gym1_types[0] == 2'd2)) +
    ((gym1_count >= 2) && (gym1_types[1] == 2'd2)) +
    ((gym1_count >= 3) && (gym1_types[2] == 2'd2)) : 2'd0;

  wire [1:0] count0_t3 = (en3) ?
    ((gym0_count >= 1) && (gym0_types[0] == 2'd3)) +
    ((gym0_count >= 2) && (gym0_types[1] == 2'd3)) +
    ((gym0_count >= 3) && (gym0_types[2] == 2'd3)) : 2'd0;

  wire [1:0] count1_t3 = (en3) ?
    ((gym1_count >= 1) && (gym1_types[0] == 2'd3)) +
    ((gym1_count >= 2) && (gym1_types[1] == 2'd3)) +
    ((gym1_count >= 3) && (gym1_types[2] == 2'd3)) : 2'd0;

  wire [1:0] count0_t4 = (en4) ?
    ((gym0_count >= 1) && (gym0_types[0] == 2'd4)) +
    ((gym0_count >= 2) && (gym0_types[1] == 2'd4)) +
    ((gym0_count >= 3) && (gym0_types[2] == 2'd4)) : 2'd0;

  wire [1:0] count1_t4 = (en4) ?
    ((gym1_count >= 1) && (gym1_types[0] == 2'd4)) +
    ((gym1_count >= 2) && (gym1_types[1] == 2'd4)) +
    ((gym1_count >= 3) && (gym1_types[2] == 2'd4)) : 2'd0;

  // Generate 6-bit patterns
  wire [5:0] pattern1 = { {1'b0, count0_t1}, {1'b0, count1_t1} };
  wire [5:0] pattern2 = { {1'b0, count0_t2}, {1'b0, count1_t2} };
  wire [5:0] pattern3 = { {1'b0, count0_t3}, {1'b0, count1_t3} };
  wire [5:0] pattern4 = { {1'b0, count0_t4}, {1'b0, count1_t4} };

  // Detect first occurrences
  wire first1 = en1;
  wire first2 = en2 && !(en1 && (pattern2 == pattern1));
  wire first3 = en3 && !( (en1 && (pattern3 == pattern1)) || 
                         (en2 && (pattern3 == pattern2)) );
  wire first4 = en4 && !( (en1 && (pattern4 == pattern1)) || 
                         (en2 && (pattern4 == pattern2)) || 
                         (en3 && (pattern4 == pattern3)) );

  // Calculate group sizes
  wire [2:0] group_size1 = first1 ? 
      1 + (en2 && (pattern2 == pattern1)) + 
          (en3 && (pattern3 == pattern1)) + 
          (en4 && (pattern4 == pattern1)) : 3'd0;

  wire [2:0] group_size2 = first2 ? 
      1 + (en3 && (pattern3 == pattern2)) + 
          (en4 && (pattern4 == pattern2)) : 3'd0;

  wire [2:0] group_size3 = first3 ? 
      1 + (en4 && (pattern4 == pattern3)) : 3'd0;

  wire [2:0] group_size4 = first4 ? 3'd1 : 3'd0;

  // Factorial LUT modulo 101 (for k:1-4)
  function automatic [6:0] fact_mod101(input [2:0] k);
    case(k)
      3'd1: fact_mod101 = 7'd1;
      3'd2: fact_mod101 = 7'd2;
      3'd3: fact_mod101 = 7'd6;
      3'd4: fact_mod101 = 7'd24;
      default: fact_mod101 = 7'd1;
    endcase
  endfunction

  // Result accumulation
  always_comb begin
    count = 7'd1;
    if (first1) count = (count * fact_mod101(group_size1)) % 7'd101;
    if (first2) count = (count * fact_mod101(group_size2)) % 7'd101;
    if (first3) count = (count * fact_mod101(group_size3)) % 7'd101;
    if (first4) count = (count * fact_mod101(group_size4)) % 7'd101;
  end
endmodule