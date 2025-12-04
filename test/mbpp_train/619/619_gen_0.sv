module move_numbers #(
  parameter MAX_LEN = 32
)(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] char_in,
  input        valid_in,
  output reg [255:0] result,
  output reg         done,
  output reg         valid_out
);

  // FSM States
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;

  // Buffers for non-digits and digits
  reg [255:0] non_digits;
  reg [255:0] digits;

  // Counters
  reg [5:0] non_dig_cnt;
  reg [5:0] dig_cnt;
  reg [5:0] total_cnt;

  // Internal signals
  wire is_digit;
  wire [5:0] non_dig_idx;
  wire [5:0] dig_idx;

  assign is_digit    = (char_in >= 8'd48) && (char_in <= 8'd57);
  assign non_dig_idx = non_dig_cnt;
  assign dig_idx     = dig_cnt;

  // Sequential logic: state, counters, buffers, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      non_digits  <= 256'b0;
      digits      <= 256'b0;
      non_dig_cnt <= 6'd0;
      dig_cnt     <= 6'd0;
      total_cnt   <= 6'd0;
      result      <= 256'b0;
      done        <= 1'b0;
      valid_out   <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done      <= 1'b0;
      valid_out <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Clear buffers and counters at start
            non_digits  <= 256'b0;
            digits      <= 256'b0;
            non_dig_cnt <= 6'd0;
            dig_cnt     <= 6'd0;
            total_cnt   <= 6'd0;
          end
        end

        PROCESSING: begin
          if (valid_in && (total_cnt < MAX_LEN)) begin
            // Store character into appropriate buffer
            if (is_digit) begin
              if (dig_cnt < MAX_LEN) begin
                // Place at position dig_cnt
                digits[dig_idx*8 +: 8] <= char_in;
                dig_cnt <= dig_cnt + 6'd1;
              end
            end else begin
              if (non_dig_cnt < MAX_LEN) begin
                // Place at position non_dig_cnt
                non_digits[non_dig_idx*8 +: 8] <= char_in;
                non_dig_cnt <= non_dig_cnt + 6'd1;
              end
            end
            total_cnt <= total_cnt + 6'd1;
          end
        end

        DONE: begin
          // Concatenate non-digits followed by digits
          result    <= {digits, non_digits} >> ((MAX_LEN - non_dig_cnt) * 8);
          // The above shift aligns so that result[0 +: non_dig_cnt*8] are non-digits
          // and following bytes are digits, given total length <= MAX_LEN.
          done      <= 1'b1;
          valid_out <= 1'b1;
        end

        default: begin
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
          next_state = PROCESSING;
      end

      PROCESSING: begin
        // Transition after MAX_LEN valid characters received
        if (total_cnt >= MAX_LEN)
          next_state = DONE;
      end

      DONE: begin
        // Go back to IDLE; wait for next start
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule