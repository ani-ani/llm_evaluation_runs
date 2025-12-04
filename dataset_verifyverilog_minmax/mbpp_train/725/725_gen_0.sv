module quote_extractor(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [127:0] text,
  output reg [127:0] results,
  output reg [1:0] valid
);

parameter IDLE = 2'b00;
parameter SCANNING = 2'b01;
parameter IN_QUOTE = 2'b10;

reg [1:0] state, next_state;
reg [4:0] byte_cnt;
reg [1:0] slot;
reg [3:0] pos;
reg start_d;

wire [7:0] cur_char = (byte_cnt < 5'd16) ? text[byte_cnt*8 +: 8] : 8'h0;
wire active = (state != IDLE);
wire last_byte = (byte_cnt == 5'd15);
wire processing = active;

always_comb begin
  next_state = state;
  case (state)
    IDLE: begin
      if (start && !start_d) begin
        next_state = SCANNING;
      end
    end
    SCANNING: begin
      if (processing) begin
        if (cur_char == 8'h22 && slot < 2 && valid[slot] == 1'b0) begin
          next_state = IN_QUOTE;
        end
      end
    end
    IN_QUOTE: begin
      if (processing) begin
        if (cur_char == 8'h22) begin
          next_state = SCANNING;
        end
      end
    end
  endcase

  // Transition to IDLE after last byte
  if ((state == SCANNING || state == IN_QUOTE) && processing && last_byte) begin
    next_state = IDLE;
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    byte_cnt <= 5'd0;
    slot <= 2'd0;
    pos <= 4'd0;
    results <= 128'h0;
    valid <= 2'b0;
    start_d <= 1'b0;
  end else begin
    start_d <= start;

    // Update state
    state <= next_state;

    // Update other registers based on current state
    case (state)
      IDLE: begin
        if (start && !start_d) begin
          // Initialize for new processing
          byte_cnt <= 5'd0;
          slot <= 2'd0;
          pos <= 4'd0;
          results <= 128'h0;
          valid <= 2'b0;
        end
        // otherwise stay idle
      end

      SCANNING: begin
        if (processing) begin
          // Quote detection
          if (cur_char == 8'h22 && slot < 2 && valid[slot] == 1'b0) begin
            // Begin new string
            pos <= 4'd0;
            // in_quote flag is not needed, rely on state
          end
          // Process the current byte (increment counter)
          if (byte_cnt < 5'd16) byte_cnt <= byte_cnt + 1;
        end
      end

      IN_QUOTE: begin
        if (processing) begin
          if (cur_char == 8'h22) begin
            // Closing quote
            if (slot == 2'b00) valid[0] <= 1'b1;
            else if (slot == 2'b01) valid[1] <= 1'b1;
            // Move to next slot if possible
            if (slot < 2'b01) slot <= slot + 1;
            pos <= 4'd0;
            // State transition back to SCANNING handled in next_state
          end else begin
            // Store character if pos < 8
            if (pos < 4'd8) begin
              if (slot == 2'b00) begin
                results[ (pos*8) +: 8 ] <= cur_char;
              end else begin
                results[ (64 + pos*8) +: 8 ] <= cur_char;
              end
              pos <= pos + 1;
            end
          end
          // Increment byte counter
          if (byte_cnt < 5'd16) byte_cnt <= byte_cnt + 1;
        end
      end
    endcase
  end
end

endmodule