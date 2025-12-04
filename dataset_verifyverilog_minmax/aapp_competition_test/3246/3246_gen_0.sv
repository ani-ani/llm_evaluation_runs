module word_descrambler(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start processing
  input [127:0] scrambled_str, // 16-character fixed input (8-bit per char)
  input [63:0] dict_words [0:7], // 8 dictionary words (8 chars each)
  input [2:0] word_count, // Actual dictionary words (0-7)
  output reg [127:0] deciphered_str, // Output string
  output reg [1:0] status, // 00:busy, 01:done, 10:ambiguous, 11:impossible
  output reg [3:0] output_length // Valid characters in output
);

  // Typedef for candidate queue entries
  typedef struct packed {
    logic [3:0] pos;        // next start position in scrambled_str (0..16)
    logic [7:0] path;       // up to 8 dict indices (4 bits each), MSB is last word index
    logic [3:0] path_len;   // number of words in path
    logic [4:0] cycles;     // cycles used for this candidate
  } cand_t;

  // Internal signals and registers
  logic [7:0] str_bytes [0:15];       // bytes of scrambled_str
  logic [7:0] dict [0:7][0:7];        // dictionary words (bytes)
  logic [3:0] dict_len [0:7];         // dictionary lengths
  logic [2:0] dict_cnt;               // actual number of dictionary words
  logic [7:0] dict_first [0:7];       // first char per dict word
  logic [7:0] dict_last  [0:7];       // last char per dict word
  logic [255:0] dict_sig [0:7];       // 256-bit signature: 256 bits (32 x [7:0]), each bit j set means char (j) count == 1
  logic [255:0] dict_sig_inv [0:7];   // inverted signature for two-letter words
  logic [7:0] sig_zero [0:7];         // zero signature for words with len<=2

  logic [7:0] cnt_full [0:15][256];   // prefix letter counts (256 entries per prefix)
  logic [4:0] cycle_counter;          // 5-bit up to 31 (we will also cap by total_expansions)
  logic [7:0] total_expansions;       // 8-bit to cap expansions <= 256

  // Candidate queue (size 32 to support up to 256 expansions with wrap-around)
  cand_t queue [0:31];
  logic [5:0] q_head, q_tail;
  logic queue_empty, queue_full;
  cand_t best_cand;

  // Solutions storage (store up to 2 solutions)
  logic [127:0] solutions [0:1];
  logic [3:0]   sol_len   [0:1];
  logic [1:0]   sol_count;

  // FSM state
  typedef enum logic [1:0] { IDLE=2'b00, WORK=2'b01, DONE=2'b10 } fsm_state_t;
  fsm_state_t fsm_state;

  // Utility: unpack 128-bit string into 16 bytes (LSB contains bytes[0])
  function [7:0] get_byte_from_128(input [127:0] data, input [3:0] idx);
    integer i;
    get_byte_from_128 = 8'b0;
    for (i = 0; i < 8; i++) begin
      if (idx == i) get_byte_from_128 = data[(i*8)+:8];
    end
  endfunction

  function void unpack_str_to_bytes();
    integer i;
    for (i = 0; i < 16; i++) begin
      str_bytes[i] = scrambled_str[(i*8)+:8];
    end
  endfunction

  // Utility: unpack 64-bit dict word j into 8 bytes
  function [7:0] get_byte_from_64(input [63:0] data, input [3:0] idx);
    integer i;
    get_byte_from_64 = 8'b0;
    for (i = 0; i < 8; i++) begin
      if (idx == i) get_byte_from_64 = data[(i*8)+:8];
    end
  endfunction

  function void unpack_dict();
    integer i, k;
    for (i = 0; i < 8; i++) begin
      for (k = 0; k < 8; k++) begin
        dict[i][k] = get_byte_from_64(dict_words[i], k);
      end
    end
  endfunction

  // Compute dictionary signatures (first, last, inner letter counts packed in 256-bit vector)
  function void compute_dict_signatures();
    integer i, k, c;
    logic [7:0] first_ch, last_ch, ch;
    logic [255:0] sig;
    for (i = 0; i < 8; i++) begin
      // length
      dict_len[i] = 4'd0;
      for (k = 0; k < 8; k++) begin
        if (dict[i][k] != 8'h00) dict_len[i] = dict_len[i] + 1;
      end
      if (dict_len[i] == 0) begin
        dict_first[i] = 8'h00;
        dict_last[i]  = 8'h00;
        dict_sig[i]   = 256'b0;
        dict_sig_inv[i] = 256'b0;
        sig_zero[i]   = 8'h00; // zero signature marker
        continue;
      end
      dict_first[i] = dict[i][0];
      dict_last[i]  = dict[i][dict_len[i]-1];
      // Build inner signature (for len>=3)
      sig = 256'b0;
      for (k = 1; k < dict_len[i]-1; k++) begin
        ch = dict[i][k];
        // set bit at position ch in sig (each inner letter must appear exactly once)
        sig[ch] = 1'b1;
      end
      dict_sig[i] = sig;
      dict_sig_inv[i] = ~sig; // for two-letter words, sig should be all zeros -> inv all ones
      // zero signature indicator for len<=2 (do not use inner letters)
      sig_zero[i] = (dict_len[i] <= 2) ? 8'hFF : 8'h00;
    end
  endfunction

  // Compute prefix letter counts for scrambled_str (16 prefixes: 0..16)
  function void compute_prefix_counts();
    integer p, ch_idx;
    for (p = 0; p <= 16; p++) begin
      for (ch_idx = 0; ch_idx < 256; ch_idx++) begin
        cnt_full[p][ch_idx] = 8'b0;
      end
    end
    for (p = 1; p <= 16; p++) begin
      for (ch_idx = 0; ch_idx < 256; ch_idx++) begin
        cnt_full[p][ch_idx] = cnt_full[p-1][ch_idx];
      end
      cnt_full[p][ str_bytes[p-1] ] = cnt_full[p][ str_bytes[p-1] ] + 1;
    end
  endfunction

  // Get inner-letter signature for scrambled_str substring [l..r-1]
  function [255:0] get_substring_inner_sig(input [3:0] l, input [3:0] r);
    integer j;
    get_substring_inner_sig = 256'b0;
    for (j = 0; j < 256; j++) begin
      // Inner letters are those strictly between first and last
      // We'll compute using: sig = sum(letter==x for indices 1..len-2)
      // Use prefix counts: count in [l, r) of char j minus first and last (if in range)
      // First index is l, last index is r-1
      if (r - l > 2) begin
        // Start with full range count
        get_substring_inner_sig[j] = cnt_full[r][j] - cnt_full[l][j];
        // Subtract first and last if they equal j
        if (str_bytes[l] == j)   get_substring_inner_sig[j] = get_substring_inner_sig[j] - 1;
        if (str_bytes[r-1] == j) get_substring_inner_sig[j] = get_substring_inner_sig[j] - 1;
        // After subtraction, each inner must be 0 or 1; keep only 1's
        get_substring_inner_sig[j] = (get_substring_inner_sig[j] == 1);
      end
      // If length <= 2, leave as 0 (no inner letters)
    end
  endfunction

  // Return signature for substring [l..r-1] (first, last, inner)
  function [517:0] get_substring_signature(input [3:0] l, input [3:0] r);
    get_substring_signature = 517'b0;
    if (r > l) begin
      get_substring_signature[7:0]   = str_bytes[l];       // first
      get_substring_signature[15:8]  = str_bytes[r-1];     // last
      get_substring_signature[771:516] = get_substring_inner_sig(l, r); // 256 bits
    end
  endfunction

  // Check if a substring [l..r) matches a dictionary word by signature
  function [3:0] match_dict_word(input [3:0] l, input [3:0] r);
    integer i;
    logic [517:0] sub_sig;
    sub_sig = get_substring_signature(l, r);
    for (i = 0; i < 8; i++) begin
      if (i >= dict_cnt) continue;
      // length must match
      if (dict_len[i] != (r - l)) continue;
      // single-letter words: exact match
      if (dict_len[i] == 4'd1) begin
        if (dict_first[i] == sub_sig[7:0]) begin
          match_dict_word = i[3:0];
          return;
        end
      end
      // two-letter words: exact match (first+last)
      if (dict_len[i] == 4'd2) begin
        if (dict_first[i] == sub_sig[7:0] && dict_last[i] == sub_sig[15:8]) begin
          match_dict_word = i[3:0];
          return;
        end
      end
      // length >=3: first/last + inner signature
      if (dict_len[i] >= 4'd3) begin
        if (dict_first[i] == sub_sig[7:0] && dict_last[i] == sub_sig[15:8]) begin
          if (dict_sig[i] == sub_sig[771:516]) begin
            match_dict_word = i[3:0];
            return;
          end
        end
      end
    end
    match_dict_word = 4'b1111; // no match
  endfunction

  // Build deciphered string from path (dict indices) with spaces
  function [127:0] build_deciphered_from_path(input [7:0] path, input [3:0] path_len);
    integer i, k, out_idx;
    logic [3:0] dict_idx;
    logic [7:0] ch;
    build_deciphered_from_path = 128'b0;
    out_idx = 0;
    for (i = 0; i < 8; i++) begin
      if (i >= path_len) break;
      // extract dict index at position i (4 bits)
      dict_idx = path[(i*4)+:4];
      for (k = 0; k < 8; k++) begin
        if (k < dict_len[dict_idx]) begin
          ch = dict[dict_idx][k];
          if (out_idx < 16) begin
            build_deciphered_from_path[(out_idx*8)+:8] = ch;
            out_idx = out_idx + 1;
          end
        end
      end
      // add a space if not the last word and we have room
      if ((i + 1 < path_len) && (out_idx < 16)) begin
        build_deciphered_from_path[(out_idx*8)+:8] = 8'h20; // space
        out_idx = out_idx + 1;
      end
    end
    // output_length is returned as 4-bit length separately
  endfunction

  // Queue push/pop (circular)
  function void queue_init();
    integer i;
    for (i = 0; i < 32; i++) begin
      queue[i] = '0;
    end
    q_head = 6'b0;
    q_tail = 6'b0;
  endfunction

  function void queue_push(input cand_t entry);
    if (queue_full) begin
      // overwrite oldest (not expected often; cap expansions prevents overflow)
      q_head = (q_head + 1) & 6'b11111;
    end
    queue[q_tail] = entry;
    q_tail = (q_tail + 1) & 6'b11111;
  endfunction

  function void queue_pop(output cand_t entry);
    entry = queue[q_head];
    q_head = (q_head + 1) & 6'b11111;
  endfunction

  // Initialize processing
  task reset_state;
    integer i;
    // Unpack inputs
    unpack_str_to_bytes();
    unpack_dict();
    dict_cnt = (word_count > 3'd7) ? 3'd7 : word_count;
    compute_dict_signatures();
    compute_prefix_counts();

    // Reset outputs
    deciphered_str = 128'b0;
    status = 2'b00;
    output_length = 4'b0;

    // Reset internals
    cycle_counter = 5'b0;
    total_expansions = 8'b0;
    queue_init();
    for (i = 0; i < 2; i++) begin
      solutions[i] = 128'b0;
      sol_len[i] = 4'b0;
    end
    sol_count = 2'b0;
  endtask

  // Expand the best candidate by one word (prioritize longest match)
  function void expand_best();
    cand_t cand, new_cand;
    integer j, k, match_idx;
    logic [3:0] max_len, match_l;
    logic [7:0] new_path;
    logic [3:0] new_path_len;
    logic [4:0] new_cycles;
    logic found;
    if (queue_empty) begin
      return;
    end
    // Get the oldest entry (best by expansion order: longer words earlier increases chance of solution)
    cand = queue[q_head];
    // Try up to 8 lengths starting from longest possible (8..1) to prioritize longest words
    match_idx = 4'b1111;
    found = 1'b0;
    if (cand.pos < 4'd16) begin
      for (j = 8; j >= 1; j--) begin
        if (cand.pos + j <= 16) begin
          match_l = match_dict_word(cand.pos, cand.pos + j);
          if (match_l != 4'b1111) begin
            match_idx = match_l;
            max_len = j[3:0];
            found = 1'b1;
            break; // take longest match at this position
          end
        end
      end
    end
    if (found) begin
      // Build new candidate
      new_cand.pos = cand.pos + max_len;
      new_cand.path = cand.path;
      new_cand.path_len = cand.path_len;
      new_cand.cycles = cand.cycles + 1;
      // Append dict index to path (shift left by 4 bits, then set lower 4 bits)
      if (new_cand.path_len < 4'd8) begin
        new_cand.path = { new_cand.path[3:0], 4'b0 } | match_idx; // shift left 4, add new 4-bit index
        new_cand.path_len = new_cand.path_len + 1;
      end else begin
        // Should not happen (max 8 words), but keep same if overflow (will likely fail due to length)
      end
      // If completed
      if (new_cand.pos == 4'd16) begin
        if (sol_count < 2) begin
          solutions[sol_count] = build_deciphered_from_path(new_cand.path, new_cand.path_len);
          sol_len[sol_count] = 4'd0; // will compute actual length below
          sol_count = sol_count + 1;
        end
      end else begin
        // Enqueue new candidate
        queue_push(new_cand);
      end
    end
    // Remove best candidate from queue (we are expanding it)
    q_head = (q_head + 1) & 6'b11111;
    total_expansions = total_expansions + 1;
  endfunction

  // Determine output length (number of valid characters) for given deciphered string
  function [3:0] compute_output_len(input [127:0] out_str);
    integer i;
    compute_output_len = 4'd0;
    for (i = 0; i < 16; i++) begin
      if (out_str[(i*8)+:8] != 8'h00) compute_output_len = compute_output_len + 1;
    end
  endfunction

  // Sequential process (FSM and control)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fsm_state <= IDLE;
      deciphered_str <= 128'b0;
      status <= 2'b00;
      output_length <= 4'b0;
      queue_init();
      cycle_counter <= 5'b0;
      total_expansions <= 8'b0;
      // Clear dict/lens signals
      dict_cnt <= 3'b0;
      for (int i = 0; i < 8; i++) begin
        dict_len[i] <= 4'b0;
        dict_first[i] <= 8'b0;
        dict_last[i] <= 8'b0;
        dict_sig[i] <= 256'b0;
        dict_sig_inv[i] <= 256'b0;
        sig_zero[i] <= 8'b0;
      end
      for (int i = 0; i < 2; i++) begin
        solutions[i] <= 128'b0;
        sol_len[i] <= 4'b0;
      end
      sol_count <= 2'b0;
    end else begin
      case (fsm_state)
        IDLE: begin
          if (start) begin
            reset_state();
            // Seed queue with the initial position (0) and empty path
            queue_push('{pos:4'd0, path:8'b0, path_len:4'd0, cycles:5'b0});
            cycle_counter <= 5'b0;
            total_expansions <= 8'b0;
            fsm_state <= WORK;
            status <= 2'b00; // busy
          end else begin
            status <= 2'b00;
          end
        end
        WORK: begin
          if (total_expansions >= 8'd255) begin
            // Time is up
            fsm_state <= DONE;
          end else begin
            // Perform one expansion per cycle
            expand_best();
            cycle_counter <= cycle_counter + 1;
            // If no more candidates, finish
            if ((q_head == q_tail) && (total_expansions >= 8'd1)) begin
              fsm_state <= DONE;
            end else if (cycle_counter >= 5'd31) begin
              // Also stop after enough cycles to guarantee <=256 expansions overall
              fsm_state <= DONE;
            end
          end
        end
        DONE: begin
          if (sol_count == 4'd1) begin
            deciphered_str <= solutions[0];
            output_length <= compute_output_len(solutions[0]);
            status <= 2'b01; // done
          end else if (sol_count >= 4'd2) begin
            deciphered_str <= solutions[0];
            output_length <= compute_output_len(solutions[0]);
            status <= 2'b10; // ambiguous
          end else begin
            deciphered_str <= 128'b0;
            output_length <= 4'b0;
            status <= 2'b11; // impossible
          end
          // Remain in DONE until start deasserted or next start
        end
        default: begin
          fsm_state <= IDLE;
        end
      endcase
    end
  end

  // Compute derived signals for empty/full queue
  assign queue_empty = (q_head == q_tail);
  assign queue_full  = ((q_tail + 1) & 6'b11111) == q_head;

endmodule