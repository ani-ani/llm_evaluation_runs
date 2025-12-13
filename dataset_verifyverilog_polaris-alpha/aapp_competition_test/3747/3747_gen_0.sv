module bulbasaur_counter(
  input clk, // clock signal
  input rst_n, // active-low synchronous reset
  input start, // pulse high to begin processing
  input [5:0] str_len, // input string length (max 64)
  input [7:0] char_in, // current ASCII character input (requires valid_char=1)
  input valid_char, // high when char_in is valid
  output reg [7:0] bulbasaur_count, // number of "Bulbasaur" formations
  output reg done // high when computation complete
);

  // State encoding
  localparam IDLE   = 2'b00;
  localparam COUNT  = 2'b01;
  localparam CALC   = 2'b10;

  reg [1:0] state, next_state;

  // Remaining characters to process
  reg [5:0] remaining_chars;

  // Character counters
  reg [7:0] cnt_B;
  reg [7:0] cnt_u;
  reg [7:0] cnt_l;
  reg [7:0] cnt_b;
  reg [7:0] cnt_a;
  reg [7:0] cnt_s;
  reg [7:0] cnt_r;

  // Min calculation pipeline registers
  reg [7:0] min_stage1_0; // min(B, u/2)
  reg [7:0] min_stage1_1; // min(l, b)
  reg [7:0] min_stage1_2; // min(a/2, s)
  reg [7:0] min_stage1_3; // r

  reg [7:0] min_stage2_0; // min(stage1_0, stage1_1)
  reg [7:0] min_stage2_1; // min(stage1_2, stage1_3)

  reg [1:0] calc_cycle; // 0..2 within CALC state

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT;
      end
      COUNT: begin
        if (remaining_chars == 6'd0)
          next_state = CALC;
      end
      CALC: begin
        if (calc_cycle == 2'd2)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      remaining_chars <= 6'd0;
      cnt_B <= 8'd0;
      cnt_u <= 8'd0;
      cnt_l <= 8'd0;
      cnt_b <= 8'd0;
      cnt_a <= 8'd0;
      cnt_s <= 8'd0;
      cnt_r <= 8'd0;
      bulbasaur_count <= 8'd0;
      done <= 1'b0;
      calc_cycle <= 2'd0;
      min_stage1_0 <= 8'd0;
      min_stage1_1 <= 8'd0;
      min_stage1_2 <= 8'd0;
      min_stage1_3 <= 8'd0;
      min_stage2_0 <= 8'd0;
      min_stage2_1 <= 8'd0;
    end else begin
      state <= next_state;
      done <= 1'b0; // default

      case (state)
        IDLE: begin
          // Wait for start; when start, initialize counters
          if (start) begin
            remaining_chars <= str_len;
            cnt_B <= 8'd0;
            cnt_u <= 8'd0;
            cnt_l <= 8'd0;
            cnt_b <= 8'd0;
            cnt_a <= 8'd0;
            cnt_s <= 8'd0;
            cnt_r <= 8'd0;
            calc_cycle <= 2'd0;
          end
        end

        COUNT: begin
          // Process valid characters while remaining_chars > 0
          if (remaining_chars != 6'd0) begin
            if (valid_char) begin
              case (char_in)
                8'd66:  cnt_B <= cnt_B + 8'd1; // 'B'
                8'd117: cnt_u <= cnt_u + 8'd1; // 'u'
                8'd108: cnt_l <= cnt_l + 8'd1; // 'l'
                8'd98:  cnt_b <= cnt_b + 8'd1; // 'b'
                8'd97:  cnt_a <= cnt_a + 8'd1; // 'a'
                8'd115: cnt_s <= cnt_s + 8'd1; // 's'
                8'd114: cnt_r <= cnt_r + 8'd1; // 'r'
                default: ;
              endcase
              remaining_chars <= remaining_chars - 6'd1;
            end
          end
          // Transition to CALC handled by next_state when remaining_chars == 0
          if (remaining_chars == 6'd0) begin
            calc_cycle <= 2'd0;
          end
        end

        CALC: begin
          // 3-cycle min computation pipeline
          if (calc_cycle == 2'd0) begin
            // Stage 1: compute divided counts and local mins
            // u_half = cnt_u >> 1, a_half = cnt_a >> 1
            begin
              reg [7:0] u_half;
              reg [7:0] a_half;
              u_half = cnt_u >> 1;
              a_half = cnt_a >> 1;

              // min(B, u_half)
              min_stage1_0 <= (cnt_B < u_half) ? cnt_B : u_half;
              // min(l, b)
              min_stage1_1 <= (cnt_l < cnt_b) ? cnt_l : cnt_b;
              // min(a_half, s)
              min_stage1_2 <= (a_half < cnt_s) ? a_half : cnt_s;
              // r
              min_stage1_3 <= cnt_r;
            end
            calc_cycle <= 2'd1;
          end else if (calc_cycle == 2'd1) begin
            // Stage 2: reduce to two mins
            min_stage2_0 <= (min_stage1_0 < min_stage1_1) ? min_stage1_0 : min_stage1_1;
            min_stage2_1 <= (min_stage1_2 < min_stage1_3) ? min_stage1_2 : min_stage1_3;
            calc_cycle <= 2'd2;
          end else begin
            // Stage 3: final min and output
            bulbasaur_count <= (min_stage2_0 < min_stage2_1) ? min_stage2_0 : min_stage2_1;
            done <= 1'b1; // pulse done for 1 cycle
            calc_cycle <= 2'd0; // prepare for next operation
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule