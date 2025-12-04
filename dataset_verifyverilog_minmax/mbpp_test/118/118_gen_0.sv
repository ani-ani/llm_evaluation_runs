module string_splitter(
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [511:0] words_out,
  output reg [3:0] word_count,
  output reg done
);

  // State machine
  localparam IDLE = 1'b0;
  localparam PROC = 1'b1;

  reg state, next_state;
  reg [3:0] cyc;                // 0..15
  reg [127:0] str_latched;
  reg [3:0] words;              // 0..4
  reg [3:0] word_start;         // 0..15
  reg word_active;              // currently building a word
  reg [3:0] idx;                // current byte index within the 16B word
  reg [127:0] accum;            // accumulated 16-byte word (left-aligned)

  // Per-byte valid mask for current word
  reg [15:0] byte_valid;        // bit j = 1 if accum[8*j+:8] is valid

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cyc <= 4'd0;
      str_latched <= 128'd0;
      words <= 4'd0;
      word_start <= 4'd0;
      word_active <= 1'b0;
      idx <= 4'd0;
      accum <= 128'd0;
      byte_valid <= 16'd0;
      words_out <= 512'd0;
      word_count <= 4'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= 1'b0;
      case (state)
        IDLE: begin
          cyc <= 4'd0;
          words <= 4'd0;
          word_start <= 4'd0;
          word_active <= 1'b0;
          idx <= 4'd0;
          accum <= 128'd0;
          byte_valid <= 16'd0;
          words_out <= 512'd0;
          word_count <= 4'd0;
          if (start) begin
            str_latched <= str_in;
          end
        end
        PROC: begin
          cyc <= cyc + 1;
          idx <= cyc;
          if (cyc < 4'd15) begin
            if (str_latched[8*cyc +: 8] == 8'h20) begin
              // Space: finalize current word if active and not already stored
              if (word_active && (words < 4)) begin
                words <= words + 1;
                // Left-align current word into 16 bytes
                words_out[512 - 128*words -: 128] <= (accum << (8*(15 - idx)));
              end
              word_active <= 1'b0;
              byte_valid <= 16'd0;
            end else begin
              // Non-space: start or continue a word
              if (!word_active) begin
                word_active <= 1'b0;
                word_start <= cyc;
                idx <= cyc;
                accum <= 128'd0;
                byte_valid <= 16'd0;
              end
              accum[8*cyc +: 8] <= str_latched[8*cyc +: 8];
              byte_valid[cyc] <= 1'b1;
              word_active <= 1'b1;
            end
          end else begin
            // Last character (cyc == 15)
            if (str_latched[8*cyc +: 8] == 8'h20) begin
              if (word_active && (words < 4)) begin
                words <= words + 1;
                words_out[512 - 128*words -: 128] <= (accum << (8*(15 - idx)));
              end
            end else begin
              if (!word_active) begin
                accum <= 128'd0;
                byte_valid <= 16'd0;
                idx <= cyc;
              end
              accum[8*cyc +: 8] <= str_latched[8*cyc +: 8];
              byte_valid[cyc] <= 1'b1;
              if (!word_active && (words < 4)) begin
                words <= words + 1;
                words_out[512 - 128*words -: 128] <= (accum << (8*(15 - cyc)));
              end
            end
            word_count <= words;
            done <= 1'b1;
          end
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: next_state = start ? PROC : IDLE;
      PROC: next_state = (cyc == 4'd15) ? IDLE : PROC;
      default: next_state = IDLE;
    endcase
  end

endmodule
