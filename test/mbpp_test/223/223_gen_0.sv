module majority_checker (
  input  [7:0] arr [0:7],
  input  [3:0] n,
  input  [7:0] x,
  output       is_majority
);

  // Clamp n to 0-8 (since 4-bit input, defensively bound it)
  wire [3:0] n_clamped = (n > 4'd8) ? 4'd8 : n;

  // Precompute indices used in unrolled binary search
  wire [3:0] mid0 = n_clamped >> 1;                 // mid for root
  wire [3:0] midL = mid0 >> 1;                      // mid of left half

  // Helper wires: index in range (0 <= idx < n_clamped)
  function automatic logic in_range;
    input [3:0] idx;
    in_range = (idx < n_clamped);
  endfunction

  // Unrolled binary search for first occurrence of x
  // "Found" here means candidate index where arr[idx] == x and it's the first.

  // Level 0 decision (root)
  wire use_left0  = in_range(mid0) && (arr[mid0] >= x);

  // Left subtree mid
  wire [3:0] idxL = midL;
  wire idxL_valid = in_range(idxL);
  wire idxL_eq    = idxL_valid && (arr[idxL] == x);

  // To check "first occurrence" property at idxL, previous index must be < x
  wire prevL_valid = (idxL > 0) && in_range(idxL - 1);
  wire prevL_lt    = prevL_valid ? (arr[idxL - 1] < x) : 1'b1; // if no valid prev, treat as -inf
  wire firstL      = idxL_eq && prevL_lt;

  // Right subtree mid of left half (only relevant if arr[midL] < x and we still stay left branch)
  // Range: (midL+1 .. mid0-1)
  wire [3:0] baseL  = midL + 1;
  wire [3:0] endL   = (mid0 > 0) ? (mid0 - 1) : 4'd0;
  wire       haveLR = (endL >= baseL);
  // Choose middle of that interval: baseL + (len>>1)
  wire [3:0] midLR  = baseL + ((endL - baseL) >> 1);
  wire       midLR_valid = haveLR && in_range(midLR);
  wire       midLR_eq    = midLR_valid && (arr[midLR] == x);

  // First occurrence condition at midLR: arr[midLR] == x and arr[midLR-1] < x (or out of range)
  wire       prevLR_valid = midLR_valid && (midLR > 0) && in_range(midLR - 1);
  wire       prevLR_lt    = prevLR_valid ? (arr[midLR - 1] < x) : 1'b1;
  wire       firstLR      = midLR_eq && prevLR_lt;

  // Right subtree of root (if arr[mid0] < x)
  // Range: (mid0+1 .. n_clamped-1)
  wire [3:0] baseR    = mid0 + 1;
  wire [3:0] endR     = (n_clamped == 0) ? 4'd0 : (n_clamped - 1);
  wire       haveR    = (n_clamped > 0) && (endR >= baseR);
  wire [3:0] midR     = baseR + ((endR - baseR) >> 1);
  wire       midR_valid = haveR && in_range(midR);
  wire       midR_eq    = midR_valid && (arr[midR] == x);

  wire       prevR_valid = midR_valid && (midR > 0) && in_range(midR - 1);
  wire       prevR_lt    = prevR_valid ? (arr[midR - 1] < x) : 1'b1;
  wire       firstR      = midR_eq && prevR_lt;

  // Combine according to binary search decision flow
  // If use_left0 (x <= arr[mid0]): search in left half
  //   Prefer firstL if valid; else firstLR
  // Else (x > arr[mid0]): search in right half -> firstR

  wire       found_left  = firstL | firstLR;
  wire [3:0] idx_left    = firstL ? idxL : midLR;

  wire       found_right = firstR;
  wire [3:0] idx_right   = midR;

  wire       found_first = use_left0 ? found_left  : found_right;
  wire [3:0] first_idx   = use_left0 ? idx_left    : idx_right;

  // Guard: if no occurrence or n_clamped == 0, output 0
  wire       valid_first = found_first && (n_clamped != 0) && in_range(first_idx);

  // Majority check: need element at (first_idx + n_clamped/2) to exist and equal x
  wire [3:0] half_n    = n_clamped >> 1;           // floor(n/2)
  wire [4:0] idx_check = {1'b0, first_idx} + {1'b0, half_n}; // up to 8+7=15 -> 4 bits; use 5 for safety
  wire       idx_check_in = (idx_check < n_clamped);

  wire       maj_cond = valid_first && idx_check_in && (arr[idx_check[3:0]] == x);

  assign is_majority = maj_cond;

endmodule