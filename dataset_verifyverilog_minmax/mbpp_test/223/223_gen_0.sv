module majority_checker (
  input [7:0] arr [0:7], // 8 elements of 8-bit data
  input [3:0] n,         // array length (0..8)
  input [7:0] x,         // element to check
  output logic is_majority // 1 if majority, 0 otherwise
);
  // n is guaranteed 0..8
  function [2:0] first_occurrence (input [7:0] arr [0:7], input [3:0] n, input [7:0] x);
    integer i;
    first_occurrence = 3'bxxx; // default: not found
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n && arr[i] == x) begin
        first_occurrence = i[2:0];
      end
    end
  endfunction

  function bit within8 (input [31:0] k); // ensure in 0..7 range for indexing
    within8 = (k >= 0) && (k <= 7);
  endfunction

  logic [2:0] found_idx;
  logic [2:0] half_idx;
  logic [31:0] sec_idx;
  logic found_valid, sec_valid;

  assign found_idx  = first_occurrence(arr, n, x);
  assign half_idx   = n[3:1];          // floor(n/2)
  assign sec_idx    = $unsigned(found_idx) + $unsigned(half_idx);
  assign found_valid = within8(found_idx) && (found_idx < n);
  assign sec_valid   = within8(sec_idx) && (sec_idx < n);

  assign is_majority = found_valid && sec_valid && (arr[sec_idx] == x);
endmodule