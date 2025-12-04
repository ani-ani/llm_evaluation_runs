module strongest_extension (
  input clk,
  input rst_n,
  input start,
  input [127:0] class_name,
  input [1023:0] extensions,
  input [2:0] num_extensions,
  output reg [2:0] strongest_idx,
  output reg done
);

  // Internal storage for the 8x16-byte extensions
  logic [7:0] ext_bytes [0:7][0:15];

  // Unpack 1024-bit vector into 8x16 byte array
  integer i, j;
  always_comb begin
    for (i = 0; i < 8; i++) begin
      for (j = 0; j < 16; j++) begin
        ext_bytes[i][j] = extensions[(i*16 + j)*8 +: 8];
      end
    end
  end

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    PRO   = 2'b01,
    DONE  = 2'b10
  } state_t;
  state_t state, next_state;

  // Counters and flags
  logic [2:0] ext_cnt;      // current extension index (0..7)
  logic [3:0] char_cnt;     // current character within extension (0..15)
  logic [4:0] cur_strength; // -16..+16 fits in 5 bits
  logic [4:0] max_strength; // -16..+16 fits in 5 bits
  logic [2:0] max_idx;      // index of strongest extension (tie-break: first)

  // Next-state logic and register updates
  always_ff @(posedge clk) begin
    if (~rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      ext_cnt     <= 3'd0;
      char_cnt    <= 4'd0;
      cur_strength <= 5'd0;
      max_strength <= 5'sh10; // lower than any possible strength
      max_idx     <= 3'd0;
      strongest_idx <= 3'd0;
    end else begin
      unique case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for processing
            ext_cnt     <= 3'd0;
            char_cnt    <= 4'd0;
            cur_strength <= 5'd0;
            // Initialize to the lowest possible strength so first valid extension wins on ties
            max_strength <= 5'sh10; // +16 is max, so 5'sh10 > any real strength
            max_idx     <= 3'd0;
            strongest_idx <= 3'd0;
            state <= PRO;
          end else begin
            state <= IDLE;
          end
        end

        PRO: begin
          if (ext_cnt < num_extensions) begin
            if (char_cnt < 4'd15) begin
              // Evaluate one character per cycle
              {char_cnt, cur_strength} <= compute_next(char_cnt, cur_strength, ext_bytes[ext_cnt][char_cnt]);
              state <= PRO;
            end else begin
              // Last character of current extension evaluated; finalize this extension
              {char_cnt, cur_strength} <= compute_next(char_cnt, cur_strength, ext_bytes[ext_cnt][char_cnt]);
              if (cur_strength > max_strength) begin
                max_strength <= cur_strength;
                max_idx     <= ext_cnt;
              end
              // Move to next extension or finish
              if ((ext_cnt + 1) < num_extensions) begin
                ext_cnt     <= ext_cnt + 1;
                char_cnt    <= 4'd0;
                cur_strength <= 5'd0;
                state       <= PRO;
              end else begin
                strongest_idx <= max_idx;
                done        <= 1'b1;
                state       <= DONE;
              end
            end
          end else begin
            // No extensions to process (num_extensions == 0): stay in PRO
            state <= PRO;
          end
        end

        DONE: begin
          done <= 1'b1;
          strongest_idx <= max_idx;
          if (start) begin
            // Start new round if requested while done=1
            ext_cnt     <= 3'd0;
            char_cnt    <= 4'd0;
            cur_strength <= 5'd0;
            max_strength <= 5'sh10;
            max_idx     <= 3'd0;
            state       <= PRO;
          end else begin
            state       <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Compute next char_cnt and cur_strength (1 cycle evaluation per character)
  function automatic {logic [3:0] next_char_cnt; logic [4:0] next_strength;}
    compute_next(input [3:0] cur_char_cnt, input [4:0] cur_strength, input [7:0] ch);
  begin
    next_char_cnt = cur_char_cnt + 4'd1;
    next_strength = cur_strength;
    if ((ch >= 8'h41) && (ch <= 8'h5A)) begin // 'A'-'Z'
      next_strength = cur_strength + 5'd1;
    end else if ((ch >= 8'h61) && (ch <= 8'h7A)) begin // 'a'-'z'
      next_strength = cur_strength - 5'd1;
    end
  end
  endfunction

endmodule
