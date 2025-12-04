module string_explosion_filter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to begin processing
  input [127:0] input_str, // 16-byte input string (8-bit per char)
  input [31:0] explosion, // 4-byte explosion pattern (8-bit per char)
  input [2:0] str_len, // actual input length (0-7) - note: interface uses 3 bits for 0-7
  input [1:0] exp_len, // actual explosion length (0-3) - note: interface uses 2 bits for 0-3
  output reg [127:0] result_str, // processed output string
  output reg [3:0] out_len, // final string length (0-15)
  output reg done // high when processing completes
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE = 2'b00,
    ITERATE = 2'b01,
    DONE = 2'b10
  } state_t;

  state_t state;
  logic first_iter;

  // Working buffer and length
  logic [15:0][7:0] working_buf;
  logic [3:0] current_len; // current length of working buffer

  // Explosion pattern bytes
  logic [7:0] explosion_bytes [0:3];
  assign explosion_bytes[0] = explosion[7:0];
  assign explosion_bytes[1] = explosion[15:8];
  assign explosion_bytes[2] = explosion[23:16];
  assign explosion_bytes[3] = explosion[31:24];

  // Signals for explosion detection
  logic [0:15] match; // match signals for each position
  logic any_match;
  logic [3:0] first_match;
  logic [15:0][7:0] new_buf; // new buffer after removal
  logic [3:0] new_length; // new length after removal

  // Combinational logic for explosion detection and new buffer
  always_comb begin
    if (state == ITERATE) begin
      // Compute match for each position
      for (int j = 0; j < 16; j++) begin
        if (j + exp_len <= current_len) begin
          match[j] = 1'b1;
          for (int k = 0; k < exp_len; k++) begin
            if (working_buf[j+k] != explosion_bytes[k]) begin
              match[j] = 1'b0;
              break;
            end
          end
        end else begin
          match[j] = 1'b0;
        end
      end

      // Find any match and first match
      any_match = 1'b0;
      first_match = 4'b1111;
      for (int j = 0; j < 16; j++) begin
        if (match[j] && !any_match) begin
          any_match = 1'b1;
          first_match = j;
        end
      end

      // Compute new buffer if match found
      if (any_match) begin
        new_length = current_len - exp_len;
        for (int i = 0; i < 16; i++) begin
          if (i < new_length) begin
            if (i < first_match) begin
              new_buf[i] = working_buf[i];
            end else begin
              new_buf[i] = working_buf[i + exp_len];
            end
          end else begin
            new_buf[i] = 8'h00;
          end
        end
      end else begin
        new_buf = working_buf;
        new_length = current_len;
      end
    end else begin
      match = 16'b0;
      any_match = 1'b0;
      first_match = 4'b1111;
      new_buf = working_buf;
      new_length = current_len;
    end
  end

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      first_iter <= 1'b0;
      working_buf <= 128'h0;
      current_len <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= ITERATE;
            first_iter <= 1'b1;
          end
        end
        ITERATE: begin
          if (first_iter) begin
            working_buf <= input_str;
            current_len <= str_len;
            first_iter <= 1'b0;
          end
          if (any_match) begin
            working_buf <= new_buf;
            current_len <= new_length;
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          if (start) begin
            state <= ITERATE;
            first_iter <= 1'b1;
          end
        end
      endcase
    end
  end

  // Output assignment
  always_comb begin
    if (state == DONE) begin
      out_len = current_len;
      if (current_len == 4'd0) begin
        result_str = { 8'h46, 8'h52, 8'h55, 8'h4C, 8'h41, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00 };
      end else begin
        result_str = working_buf;
      end
      done = 1'b1;
    end else begin
      out_len = 4'd0;
      result_str = 128'h0;
      done = 1'b0;
    end
  end

endmodule