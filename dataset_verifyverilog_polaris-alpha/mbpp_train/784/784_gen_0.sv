module first_even_odd_product(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] list [0:7],
  output reg [15:0] product,
  output reg done,
  output reg found_pair
);

  // State encodings
  localparam IDLE  = 2'b00;
  localparam SCAN  = 2'b01;
  localparam FINAL = 2'b10;

  reg [1:0] state, next_state;

  reg [3:0] idx;                // 0..7 index
  reg       start_d;            // start edge detection

  reg       even_found;
  reg [7:0] even_val;
  reg       odd_found;
  reg [7:0] odd_val;

  // Edge detect for start (treat rising edge as start event)
  wire start_pulse = start & ~start_d;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      start_d     <= 1'b0;
      idx         <= 4'd0;
      even_found  <= 1'b0;
      even_val    <= 8'd0;
      odd_found   <= 1'b0;
      odd_val     <= 8'd0;
      product     <= 16'd0;
      done        <= 1'b0;
      found_pair  <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0; // ensure done low in idle
          if (start_pulse) begin
            // initialize scan
            idx        <= 4'd0;
            even_found <= 1'b0;
            odd_found  <= 1'b0;
          end
        end

        SCAN: begin
          done <= 1'b0;
          // Check current element at idx
          if (!even_found && (list[idx][0] == 1'b0)) begin
            even_found <= 1'b1;
            even_val   <= list[idx];
          end
          if (!odd_found && (list[idx][0] == 1'b1)) begin
            odd_found <= 1'b1;
            odd_val   <= list[idx];
          end

          // Increment index until last element processed
          if (idx < 4'd7) begin
            idx <= idx + 4'd1;
          end
        end

        FINAL: begin
          // Generate results for exactly one cycle
          if (even_found && odd_found) begin
            product    <= even_val * odd_val;
            found_pair <= 1'b1;
          end else begin
            product    <= 16'hFFFF;
            found_pair <= 1'b0;
          end
          done <= 1'b1;
        end

        default: begin
          // safety defaults
          done       <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = SCAN;
      end

      SCAN: begin
        // After processing index 7 (8th element), move to FINAL next cycle
        if (idx == 4'd7)
          next_state = FINAL;
      end

      FINAL: begin
        // Done is asserted exactly one cycle; then return to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule