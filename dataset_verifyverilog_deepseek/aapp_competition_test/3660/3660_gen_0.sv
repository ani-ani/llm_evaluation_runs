module sticker_message_assembler(
  input clk,
  input rst_n,
  input start,
  input [63:0] message,
  input [2:0] num_stickers,
  input [31:0] sticker_word_0,
  input [15:0] sticker_price_0,
  input [31:0] sticker_word_1,
  input [15:0] sticker_price_1,
  input [31:0] sticker_word_2,
  input [15:0] sticker_price_2,
  input [31:0] sticker_word_3,
  input [15:0] sticker_price_3,
  output reg done,
  output reg [15:0] min_cost,
  output reg impossible
);

  // State machine states
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    CHECK_STICKERS,
    CALCULATE,
    DONE
  } state_t;

  reg [3:0] current_state;
  reg [3:0] next_state;

  // Sticker iteration registers
  reg [1:0] sticker_idx;
  reg [2:0] start_pos;
  reg [3:0] stickers_used;
  reg [15:0] cost;
  reg [1:0] coverage [0:7];
  reg [15:0] best_cost;
  reg best_valid;

  // Combinational signals
  reg [3:0] valid_stickers;

  // Temporary variables
  integer i;
  reg [7:0] sticker_char;
  reg [7:0] msg_char;
  reg valid_placement;
  reg [1:0] new_coverage [0:7];
  reg layer_exceeded;

  // State machine transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Combinational next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = INIT;
      INIT: next_state = CHECK_STICKERS;
      CHECK_STICKERS: begin
        if (stickers_used == num_stickers || sticker_idx == 3) next_state = CALCULATE;
        else if (start_pos == 4) next_state = CHECK_STICKERS; // Will increment sticker_idx
        else next_state = CHECK_STICKERS;
      end
      CALCULATE: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      min_cost <= 0;
      impossible <= 0;
      sticker_idx <= 0;
      start_pos <= 0;
      cost <= 0;
      best_cost <= 16'hFFFF;
      best_valid <= 0;
      stickers_used <= 0;
      for (i=0; i<8; i++) coverage[i] <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          impossible <= 0;
          if (start) begin
            cost <= 0;
            best_cost <= 16'hFFFF;
            best_valid <= 0;
            stickers_used <= 0;
            for (i=0; i<8; i++) coverage[i] <= 0;
            sticker_idx <= 0;
            start_pos <= 0;
          end
        end
        INIT: begin
          // Initialize registers for sticker iteration
          sticker_idx <= 0;
          start_pos <= 0;
        end
        CHECK_STICKERS: begin
          // Iterate through each sticker and starting position
          if (stickers_used[sticker_idx] || sticker_idx >= num_stickers) begin
            // Skip this sticker
            sticker_idx <= sticker_idx + 1;
            start_pos <= 0;
          end else begin
            // Check current sticker placement
            valid_placement = 1;
            layer_exceeded = 0;
            for (i=0; i<4; i++) begin
              sticker_char = i<2 ? sticker_word_0[(i*8)+:8] :
                             i<4 ? sticker_word_1[(i*8)+:8] :
                             sticker_word_2[(i*8)+:8]; // Fix indexing if needed
              if (start_pos + i < 8) begin
                msg_char = message[(start_pos+i)*8 +: 8];
                if (sticker_char != 8'h20 && sticker_char != msg_char) valid_placement = 0;
              end
            end

            // Create new coverage
            for (i=0; i<8; i++) new_coverage[i] = coverage[i];
            for (i=0; i<4; i++) begin
              if (start_pos + i >= 8) continue;
              sticker_char = sticker_idx == 0 ? sticker_word_0[i*8 +:8] :
                              sticker_idx == 1 ? sticker_word_1[i*8 +:8] :
                              sticker_idx == 2 ? sticker_word_2[i*8 +:8] :
                              sticker_word_3[i*8 +:8];
              if (sticker_char != 8'h20) begin
                if (new_coverage[start_pos+i] == 2) layer_exceeded = 1;
                else new_coverage[start_pos+i] = new_coverage[start_pos+i] + 1;
              end
            end

            // Update if valid
            if (valid_placement && !layer_exceeded) begin
              stickers_used <= stickers_used | (1 << sticker_idx);
              cost <= cost + (sticker_idx == 0 ? sticker_price_0 :
                              sticker_idx == 1 ? sticker_price_1 :
                              sticker_idx == 2 ? sticker_price_2 :
                              sticker_price_3);
              for (i=0; i<8; i++) coverage[i] <= new_coverage[i];
              sticker_idx <= 0;
              start_pos <= 0;
            end else begin
              if (start_pos < 4) start_pos <= start_pos + 1;
              else begin
                sticker_idx <= sticker_idx + 1;
                start_pos <= 0;
              end
            end
          end
        end
        CALCULATE: begin
          // Check if all positions are covered
          valid_placement = 1;
          for (i=0; i<8; i++) begin
            if (coverage[i] == 0) valid_placement = 0;
          end

          if (valid_placement) begin
            if (cost < best_cost) begin
              best_cost <= cost;
              best_valid <= 1;
            end
          end else if (stickers_used < num_stickers && sticker_idx < 3) begin
            // Try again (limited backtracking)
            sticker_idx <= sticker_idx + 1;
            start_pos <= 0;
            current_state <= CHECK_STICKERS;
          end
        end
        DONE: begin
          done <= 1;
          impossible <= !best_valid;
          min_cost <= best_valid ? best_cost : 0;
        end
      endcase
    end
  end
endmodule