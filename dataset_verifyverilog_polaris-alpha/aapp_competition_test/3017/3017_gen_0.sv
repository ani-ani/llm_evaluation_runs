module count_power_substrings(
  input clk,              // clock signal
  input rst_n,            // active-low reset
  input start,            // start computation
  input [15:0] n,         // max number to check (0 ≤ n ≤ 65535)
  input [4:0][3:0] power_str, // 5-digit BCD substring (each digit 4 bits, MSD first)
  input [2:0] substr_len, // actual substring length (1-5)
  output reg [16:0] count, // match count
  output reg done          // high when computation completes
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE           = 3'd0,
    LOAD           = 3'd1,
    CONVERT_BCD    = 3'd2,
    CHECK_SUBSTR   = 3'd3,
    INCREMENT      = 3'd4,
    DONE_STATE     = 3'd5
  } state_t;

  state_t state, next_state;

  // Registers
  reg [15:0] current_k;
  reg [15:0] num_reg;
  reg [3:0]  bcd0; // ones
  reg [3:0]  bcd1; // tens
  reg [3:0]  bcd2; // hundreds
  reg [3:0]  bcd3; // thousands
  reg [3:0]  bcd4; // ten-thousands

  reg        match;

  // Sequential state, outputs, and main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      count      <= 17'd0;
      done       <= 1'b0;
      current_k  <= 16'd0;
      num_reg    <= 16'd0;
      bcd0       <= 4'd0;
      bcd1       <= 4'd0;
      bcd2       <= 4'd0;
      bcd3       <= 4'd0;
      bcd4       <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done  <= 1'b0;
          count <= 17'd0;
          if (start) begin
            current_k <= 16'd0;
          end
        end

        LOAD: begin
          // Load current number into working register for BCD conversion
          num_reg <= current_k;
        end

        CONVERT_BCD: begin
          // Combinational-style within clocked block: direct arithmetic BCD extraction
          // num_reg <= current_k from previous cycle
          bcd0 <= num_reg % 10;
          bcd1 <= (num_reg / 10) % 10;
          bcd2 <= (num_reg / 100) % 10;
          bcd3 <= (num_reg / 1000) % 10;
          bcd4 <= (num_reg / 10000) % 10;
        end

        CHECK_SUBSTR: begin
          // match is computed in separate always_comb block
          if (match)
            count <= count + 17'd1;
        end

        INCREMENT: begin
          if (current_k < n)
            current_k <= current_k + 16'd1;
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
          // safety
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end

      LOAD: begin
        next_state = CONVERT_BCD;
      end

      CONVERT_BCD: begin
        next_state = CHECK_SUBSTR;
      end

      CHECK_SUBSTR: begin
        next_state = INCREMENT;
      end

      INCREMENT: begin
        if (current_k < n)
          next_state = LOAD;
        else
          next_state = DONE_STATE;
      end

      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_STATE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Substring match logic
  // Build BCD digit array: [MSD..LSD] = [bcd4,bcd3,bcd2,bcd1,bcd0]
  wire [3:0] dig[4:0];
  assign dig[4] = bcd4;
  assign dig[3] = bcd3;
  assign dig[2] = bcd2;
  assign dig[1] = bcd1;
  assign dig[0] = bcd0;

  reg match_pos0, match_pos1, match_pos2, match_pos3, match_pos4;

  always @(*) begin
    // Default no match
    match_pos0 = 1'b0;
    match_pos1 = 1'b0;
    match_pos2 = 1'b0;
    match_pos3 = 1'b0;
    match_pos4 = 1'b0;

    // Guard: substr_len between 1 and 5 is assumed; out-of-range yields no match
    case (substr_len)
      3'd1: begin
        // positions 0..4
        match_pos0 = (dig[4] == power_str[0]);
        match_pos1 = (dig[3] == power_str[0]);
        match_pos2 = (dig[2] == power_str[0]);
        match_pos3 = (dig[1] == power_str[0]);
        match_pos4 = (dig[0] == power_str[0]);
      end

      3'd2: begin
        // positions 0..3
        match_pos0 = (dig[4] == power_str[0]) && (dig[3] == power_str[1]);
        match_pos1 = (dig[3] == power_str[0]) && (dig[2] == power_str[1]);
        match_pos2 = (dig[2] == power_str[0]) && (dig[1] == power_str[1]);
        match_pos3 = (dig[1] == power_str[0]) && (dig[0] == power_str[1]);
      end

      3'd3: begin
        // positions 0..2
        match_pos0 = (dig[4] == power_str[0]) && (dig[3] == power_str[1]) && (dig[2] == power_str[2]);
        match_pos1 = (dig[3] == power_str[0]) && (dig[2] == power_str[1]) && (dig[1] == power_str[2]);
        match_pos2 = (dig[2] == power_str[0]) && (dig[1] == power_str[1]) && (dig[0] == power_str[2]);
      end

      3'd4: begin
        // positions 0..1
        match_pos0 = (dig[4] == power_str[0]) && (dig[3] == power_str[1]) && (dig[2] == power_str[2]) && (dig[1] == power_str[3]);
        match_pos1 = (dig[3] == power_str[0]) && (dig[2] == power_str[1]) && (dig[1] == power_str[2]) && (dig[0] == power_str[3]);
      end

      3'd5: begin
        // position 0 only
        match_pos0 = (dig[4] == power_str[0]) && (dig[3] == power_str[1]) && (dig[2] == power_str[2]) && (dig[1] == power_str[3]) && (dig[0] == power_str[4]);
      end

      default: begin
        // no valid substring length -> no match
      end
    endcase
  end

  assign match = match_pos0 | match_pos1 | match_pos2 | match_pos3 | match_pos4;

endmodule