module strongest_extension (
  input        clk,
  input        rst_n,
  input        start,
  input [127:0] class_name,
  input [1023:0] extensions,
  input [2:0]  num_extensions,
  output reg [2:0] strongest_idx,
  output reg       done
);

  // State encoding
  localparam IDLE     = 2'b00;
  localparam LOAD_EXT = 2'b01;
  localparam PROCESS  = 2'b10;
  localparam FINISH   = 2'b11;

  reg [1:0] state, next_state;

  // Per-extension and global tracking
  reg [2:0] ext_idx;          // current extension index
  reg [3:0] char_idx;         // 0-15
  reg signed [5:0] strength;  // -16..+16 is enough for 16 chars

  reg signed [5:0] max_strength;
  reg [2:0]        max_idx;

  // Current character
  wire [7:0] current_char;
  assign current_char = extensions[ (ext_idx*128) + (char_idx*8) +: 8 ];

  // Character classification
  wire is_capital;
  wire is_lowercase;

  assign is_capital   = (current_char >= 8'h41) && (current_char <= 8'h5A);
  assign is_lowercase = (current_char >= 8'h61) && (current_char <= 8'h7A);

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_EXT;
        end
      end
      LOAD_EXT: begin
        next_state = PROCESS;
      end
      PROCESS: begin
        if (char_idx == 4'd15) begin
          // after processing last character this cycle, go to LOAD_EXT or FINISH next
          if (ext_idx + 3'd1 < num_extensions)
            next_state = LOAD_EXT;
          else
            next_state = FINISH;
        end
      end
      FINISH: begin
        // stay here until reset or new start; spec implies done asserted when complete
        // no auto-restart
        next_state = FINISH;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      ext_idx       <= 3'd0;
      char_idx      <= 4'd0;
      strength      <= 6'sd0;
      max_strength  <= -6'sd32; // smaller than minimum possible (-16)
      max_idx       <= 3'd0;
      strongest_idx <= 3'd0;
      done          <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize search
            ext_idx      <= 3'd0;
            char_idx     <= 4'd0;
            strength     <= 6'sd0;
            max_strength <= -6'sd32;
            max_idx      <= 3'd0;
          end
        end

        LOAD_EXT: begin
          // Start processing a new extension
          char_idx  <= 4'd0;
          strength  <= 6'sd0;
        end

        PROCESS: begin
          // Update strength based on current_char
          if (is_capital && !is_lowercase)
            strength <= strength + 6'sd1;
          else if (is_lowercase && !is_capital)
            strength <= strength - 6'sd1;
          else
            strength <= strength;

          // Advance character index
          if (char_idx < 4'd15) begin
            char_idx <= char_idx + 4'd1;
          end else begin
            // Completed 16 characters for this extension
            // Evaluate strength at end of extension; first-occurrence on ties
            if (strength > max_strength) begin
              max_strength <= strength;
              max_idx      <= ext_idx;
            end

            // Move to next extension if any (next_state logic handles whether we go to LOAD_EXT or FINISH)
            if (ext_idx + 3'd1 < num_extensions) begin
              ext_idx  <= ext_idx + 3'd1;
            end
          end
        end

        FINISH: begin
          // Latch final result once when entering FINISH
          done          <= 1'b1;
          strongest_idx <= max_idx;
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule