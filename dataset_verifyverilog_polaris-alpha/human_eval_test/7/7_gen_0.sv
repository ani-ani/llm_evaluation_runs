module string_substring_filter(
  input        clk,
  input        rst_n,
  input        start,
  input  [2:0] num_strings,
  input  [511:0] strings_packed,
  input  [23:0] substring,
  input  [1:0]  substring_len,
  output reg [7:0] match_mask,
  output reg       done
);

  // FSM state encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CHECK = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  reg [2:0] idx;            // current string index (0-7)
  reg [7:0] match_mask_next;
  reg [2:0] idx_next;
  reg       done_next;

  // Extract substring bytes
  wire [7:0] sub0 = substring[7:0];    // first character (LSB)
  wire [7:0] sub1 = substring[15:8];   // second character
  wire [7:0] sub2 = substring[23:16];  // third character

  // Combinational: substring match for current index
  function automatic logic match_substring(
    input [63:0] s,
    input [7:0]  c0,
    input [7:0]  c1,
    input [7:0]  c2,
    input [1:0]  len
  );
    logic found;
    found = 1'b0;

    unique case (len)
      2'b01: begin // length 1
        if (s[7:0]   == c0) found = 1'b1;
        else if (s[15:8]  == c0) found = 1'b1;
        else if (s[23:16] == c0) found = 1'b1;
        else if (s[31:24] == c0) found = 1'b1;
        else if (s[39:32] == c0) found = 1'b1;
        else if (s[47:40] == c0) found = 1'b1;
        else if (s[55:48] == c0) found = 1'b1;
        else if (s[63:56] == c0) found = 1'b1;
      end
      2'b10: begin // length 2
        if (s[15:0]   == {c1,c0}) found = 1'b1;
        else if (s[23:8]  == {c1,c0}) found = 1'b1;
        else if (s[31:16] == {c1,c0}) found = 1'b1;
        else if (s[39:24] == {c1,c0}) found = 1'b1;
        else if (s[47:32] == {c1,c0}) found = 1'b1;
        else if (s[55:40] == {c1,c0}) found = 1'b1;
        else if (s[63:48] == {c1,c0}) found = 1'b1;
      end
      2'b11: begin // length 3
        if (s[23:0]   == {c2,c1,c0}) found = 1'b1;
        else if (s[31:8]  == {c2,c1,c0}) found = 1'b1;
        else if (s[39:16] == {c2,c1,c0}) found = 1'b1;
        else if (s[47:24] == {c2,c1,c0}) found = 1'b1;
        else if (s[55:32] == {c2,c1,c0}) found = 1'b1;
        else if (s[63:40] == {c2,c1,c0}) found = 1'b1;
      end
      default: begin
        found = 1'b0;
      end
    endcase

    return found;
  endfunction

  // Current string slice
  wire [63:0] curr_string = strings_packed[ (idx*64) +: 64 ];

  // Next-state logic
  always @* begin
    next_state      = state;
    match_mask_next = match_mask;
    idx_next        = idx;
    done_next       = done;

    case (state)
      IDLE: begin
        done_next       = 1'b0;
        match_mask_next = 8'b0;
        idx_next        = 3'd0;
        if (start) begin
          next_state = CHECK;
        end
      end

      CHECK: begin
        done_next = 1'b0;
        // Process current index if within num_strings
        if (idx < num_strings) begin
          if (match_substring(curr_string, sub0, sub1, sub2, substring_len)) begin
            match_mask_next[idx] = 1'b1;
          end
        end

        if (idx == 3'd7) begin
          next_state = DONE;
        end
        idx_next = idx + 3'd1;
      end

      DONE: begin
        done_next = 1'b1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state      = IDLE;
        match_mask_next = 8'b0;
        idx_next        = 3'd0;
        done_next       = 1'b0;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      match_mask <= 8'b0;
      idx        <= 3'd0;
      done       <= 1'b0;
    end else begin
      state      <= next_state;
      match_mask <= match_mask_next;
      idx        <= idx_next;
      done       <= done_next;
    end
  end

endmodule