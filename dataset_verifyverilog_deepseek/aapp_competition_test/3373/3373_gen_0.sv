module longest_balanced_parentheses(
  input clk,
  input rst_n,
  input start,
  input [1:0][5:0] pieces, // [2][5:0] for 3 pieces
  output reg [4:0] max_length,
  output reg done
);

  // Precompute functions
  function automatic signed [3:0] compute_balance(input [5:0] piece);
    reg [2:0] count;
    begin
      count = piece[0] + piece[1] + piece[2] + piece[3] + piece[4] + piece[5];
      compute_balance = 2*signed'(count) - 6;
    end
  endfunction

  function automatic [2:0] compute_max_valid(input [5:0] piece);
    reg [2:0] max_valid;
    integer i,j;
    reg signed [3:0] balance;
    begin
      max_valid = 0;
      for (i=0; i<6; i=i+1) begin
        balance = 0;
        for (j=i; j<6; j=j+1) begin
          balance = balance + (piece[j] ? 1 : -1);
          if (balance < 0) break;
          if (balance == 0) begin
            if ((j-i+1) > max_valid) max_valid = j-i+1;
          end
        end
      end
      compute_max_valid = max_valid;
    end
  endfunction

  function automatic compute_is_balanced(input [5:0] piece);
    reg signed [3:0] balance;
    integer i;
    reg valid;
    begin
      balance = 0;
      valid = 1;
      for (i=0; i<6; i=i+1) begin
        balance = balance + (piece[i] ? 1 : -1);
        if (balance < 0) valid = 0;
      end
      compute_is_balanced = valid & (balance == 0);
    end
  endfunction

  function automatic signed [3:0] compute_min_balance(input [5:0] piece);
    reg signed [3:0] balance, min_bal;
    integer i;
    begin
      balance = 0;
      min_bal = 0;
      for (i=0; i<6; i=i+1) begin
        balance = balance + (piece[i] ? 1 : -1);
        if (balance < min_bal) min_bal = balance;
      end
      compute_min_balance = min_bal;
    end
  endfunction

  // Precomputed values for each piece
  wire [2:0] p0_max_val = compute_max_valid(pieces[0]);
  wire signed [3:0] p0_bal = compute_balance(pieces[0]);
  wire p0_balanced = compute_is_balanced(pieces[0]);
  wire signed [3:0] p0_min_bal = compute_min_balance(pieces[0]);

  wire [2:0] p1_max_val = compute_max_valid(pieces[1]);
  wire signed [3:0] p1_bal = compute_balance(pieces[1]);
  wire p1_balanced = compute_is_balanced(pieces[1]);
  wire signed [3:0] p1_min_bal = compute_min_balance(pieces[1]);

  wire [2:0] p2_max_val = compute_max_valid(pieces[2]);
  wire signed [3:0] p2_bal = compute_balance(pieces[2]);
  wire p2_balanced = compute_is_balanced(pieces[2]);
  wire signed [3:0] p2_min_bal = compute_min_balance(pieces[2]);

  // State registers
  reg signed [3:0] curr_bal;
  reg [4:0] curr_len;
  reg [1:0] step;
  reg [4:0] best;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      curr_bal <= 0;
      curr_len <= 0;
      best <= 0;
      step <= 0;
      done <= 0;
      max_length <= 0;
    end
    else begin
      done <= 0;

      if (start) begin // Cycle 0: Initialize
        curr_bal <= 0;
        curr_len <= 0;
        best <= (p0_max_val > p1_max_val) ? p0_max_val :
               ((p1_max_val > p2_max_val) ? p1_max_val : p2_max_val);
        step <= 1;
      end
      else if (step == 1) begin // Cycle 1: Process piece0
        best <= (best > p0_max_val) ? best : p0_max_val;
        process_piece(p0_bal, p0_min_bal, p0_balanced, p0_max_val);
        step <= 2;
      end
      else if (step == 2) begin // Cycle 2: Process piece1
        best <= (best > p1_max_val) ? best : p1_max_val;
        process_piece(p1_bal, p1_min_bal, p1_balanced, p1_max_val);
        step <= 3;
      end
      else if (step == 3) begin // Cycle 3: Process piece2
        best <= (best > p2_max_val) ? best : p2_max_val;
        process_piece(p2_bal, p2_min_bal, p2_balanced, p2_max_val);
        step <= 0;
        done <= 1;
        max_length <= best;
      end
      else begin
        step <= 0;
      end
    end
  end

  task process_piece(
    input signed [3:0] p_bal,
    input signed [3:0] p_min_bal,
    input p_balanced,
    input [2:0] p_max_val
  );
    begin
      // Only update state if adding piece doesn't break balance
      if (curr_bal + p_min_bal >= 0) begin
        curr_len = curr_len + 6;
        curr_bal = curr_bal + p_bal;
        if (curr_bal == 0 && curr_len > best)
          best = curr_len;
      end
      else if (p_balanced && p_max_val > best) begin
        best = p_max_val;
        curr_bal = 0;
        curr_len = 0;
      end
      else begin
        curr_bal = 0;
        curr_len = 0;
      end
      // Always check current state
      if (curr_bal == 0 && curr_len > best) best = curr_len;
    end
  endtask
endmodule