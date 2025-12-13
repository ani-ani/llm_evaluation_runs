module fence_painter(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0]        num_offers,
  input  [7:0][15:0]  offer_data, // per offer: [15:13]=color, [12:9]=start, [8:5]=end
  output reg [3:0]    min_count,
  output reg          impossible,
  output reg          done
);

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_RUN   = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Registers
  reg [7:0] current_mask;      // iterates from 1 to (1<<num_offers)-1
  reg [3:0] best_count;        // tracks minimum offers
  reg       any_valid;         // at least one valid combination found

  // Combinational signals for current combination
  reg [15:0] coverage;
  reg [7:0]  color_present;
  reg [3:0]  offer_count;
  reg [2:0]  color_count;
  reg        valid_combination;

  // Derived max mask based on num_offers
  wire [7:0] max_mask;
  assign max_mask = (num_offers == 0) ? 8'b0 : ((8'b1 << num_offers) - 1'b1);

  integer i;

  // Combinational evaluation for current_mask
  always @* begin
    coverage       = 16'b0;
    color_present  = 8'b0;
    offer_count    = 4'd0;

    // For each offer, if bit set in current_mask, include its coverage and color
    for (i = 0; i < 8; i = i + 1) begin
      if (current_mask[i] && (i < num_offers)) begin
        // Extract fields
        // offer_data[i][15:13] = color (3 bits)
        // offer_data[i][12:9]  = start (4 bits)
        // offer_data[i][8:5]   = end   (4 bits)
        // Build segment coverage
        // Ensure indices are within 0-15 by masking
        // Note: assume inputs are valid per spec.
        reg [2:0] color;
        reg [3:0] s_idx;
        reg [3:0] e_idx;
        reg [15:0] seg_mask;

        color   = offer_data[i][15:13];
        s_idx   = offer_data[i][12:9];
        e_idx   = offer_data[i][8:5];
        seg_mask = 16'b0;

        if (e_idx >= s_idx) begin
          reg [4:0] len;
          len = e_idx - s_idx + 1;
          if (len > 0) begin
            if (len >= 16)
              seg_mask = 16'hFFFF;
            else
              seg_mask = ((16'hFFFF >> (16 - len)) << s_idx);
          end
        end

        coverage = coverage | seg_mask;
        color_present[color] = 1'b1;
        offer_count = offer_count + 1'b1;
      end
    end

    // Count colors (up to 8 colors)
    color_count = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (color_present[i])
        color_count = color_count + 1'b1;
    end

    // Check validity
    valid_combination = (coverage == 16'hFFFF) && (color_count <= 3);
  end

  // Next state logic and control
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && (num_offers != 0)) begin
          next_state = S_RUN;
        end else if (start && (num_offers == 0)) begin
          next_state = S_DONE;
        end
      end
      S_RUN: begin
        if (current_mask == max_mask) begin
          next_state = S_DONE;
        end
      end
      S_DONE: begin
        // Wait for next start to restart
        if (start) begin
          if (num_offers != 0)
            next_state = S_RUN;
          else
            next_state = S_DONE;
        end
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      current_mask<= 8'd0;
      best_count  <= 4'd0;
      any_valid   <= 1'b0;
      min_count   <= 4'd0;
      impossible  <= 1'b0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          min_count  <= 4'd0;
          any_valid  <= 1'b0;
          best_count <= 4'd0;
          current_mask <= 8'd1; // start from 1 (non-empty set)
          // If num_offers==0 and start, handled in next_state (S_DONE)
        end

        S_RUN: begin
          // Evaluate current_mask result (from combinational block)
          if (valid_combination) begin
            if (!any_valid || (offer_count < best_count)) begin
              best_count <= offer_count;
            end
            any_valid <= 1'b1;
          end

          // Advance mask or finish
          if (current_mask == max_mask) begin
            // Will transition to S_DONE in next_state
          end else begin
            current_mask <= current_mask + 8'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          if (any_valid) begin
            min_count  <= best_count;
            impossible <= 1'b0;
          end else begin
            min_count  <= 4'd0;
            impossible <= 1'b1;
          end
          // Keep results stable until next reset/start sequence drives state
        end

        default: begin
          // Safety
          state       <= S_IDLE;
          current_mask<= 8'd0;
          best_count  <= 4'd0;
          any_valid   <= 1'b0;
          min_count   <= 4'd0;
          impossible  <= 1'b0;
          done        <= 1'b0;
        end
      endcase
    end
  end

endmodule