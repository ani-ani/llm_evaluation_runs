module quote_extractor (
  input clk,
  input rst_n,
  input start,
  input [127:0] text,
  output reg [127:0] results,
  output reg [1:0] valid
);

  typedef enum logic [1:0] { 
    IDLE,
    SCANNING,
    IN_QUOTE
  } state_t;

  reg [1:0] state;
  reg [1:0] next_state;
  reg [3:0] current_char;
  reg [3:0] next_current_char;
  reg string_idx;
  reg next_string_idx;
  reg [2:0] byte_ptr;
  reg [2:0] next_byte_ptr;
  reg [127:0] next_results;
  reg [1:0] next_valid;
  wire [7:0] current_byte;

  assign current_byte = text >> (current_char * 8);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_char <= 4'h0;
      string_idx <= 1'b0;
      byte_ptr <= 3'h0;
      results <= 128'h0;
      valid <= 2'b00;
    end else begin
      state <= next_state;
      current_char <= next_current_char;
      string_idx <= next_string_idx;
      byte_ptr <= next_byte_ptr;
      results <= next_results;
      valid <= next_valid;
    end
  end

  always_comb begin
    next_state = state;
    next_current_char = current_char;
    next_string_idx = string_idx;
    next_byte_ptr = byte_ptr;
    next_results = results;
    next_valid = valid;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = SCANNING;
          next_current_char = 4'h0;
          next_string_idx = 1'b0;
          next_byte_ptr = 3'h0;
          next_results = 128'h0;
          next_valid = 2'b00;
        end
      end

      SCANNING: begin
        if (current_char == 4'hF) begin
          next_state = IDLE;
        end else begin
          next_current_char = current_char + 1;
        end

        if (current_byte == 8'h22 && string_idx < 2) begin
          next_state = IN_QUOTE;
          next_byte_ptr = 3'h0;
        end
      end

      IN_QUOTE: begin
        if (current_byte == 8'h22) begin
          next_valid[string_idx] = 1'b1;
          if (!string_idx) next_string_idx = 1'b1;
          next_state = SCANNING;
        end else begin
          if (byte_ptr < 3'h7) begin
            case (string_idx)
              0: next_results[byte_ptr*8 +: 8] = current_byte;
              1: next_results[64 + byte_ptr*8 +: 8] = current_byte;
            endcase
            next_byte_ptr = byte_ptr + 1;
          end
        end
        
        if (current_char == 4'hF) begin
          next_state = IDLE;
        end else begin
          if (current_byte != 8'h22) next_current_char = current_char + 1;
        end
      end
    endcase
  end
endmodule