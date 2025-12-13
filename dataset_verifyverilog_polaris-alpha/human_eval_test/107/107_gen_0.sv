module palindrome_counter(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       start,
  input  wire [7:0] n,
  output reg  [7:0] even_count,
  output reg  [7:0] odd_count,
  output reg        done
);

  // FSM States
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE       = 2'b10
  } state_t;

  state_t state, next_state;

  reg [7:0] n_reg;      // Latched input n
  reg [7:0] i;          // Current number

  // Combinational palindrome and parity logic
  reg        is_pal;
  reg        is_even;
  reg [3:0]  hundreds;
  reg [3:0]  tens;
  reg [3:0]  units;

  always @(*) begin
    // Default
    is_pal  = 1'b0;
    is_even = 1'b0;
    hundreds = 4'd0;
    tens     = 4'd0;
    units    = 4'd0;

    if (state == PROCESSING && i >= 8'd1 && i <= n_reg) begin
      // Compute digits
      hundreds = i / 8'd100;
      tens     = (i % 8'd100) / 8'd10;
      units    = i % 8'd10;

      // Palindrome check based on number of digits
      if (i < 8'd10) begin
        // 1-digit: always palindrome
        is_pal = 1'b1;
      end else if (i < 8'd100) begin
        // 2-digit: tens == units
        is_pal = (tens == units);
      end else begin
        // 3-digit (since max 255): hundreds == units
        is_pal = (hundreds == units);
      end

      // Parity
      is_even = ~i[0];
    end
  end

  // FSM Next State Logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      PROCESSING: begin
        if (i > n_reg && n_reg != 8'd0) begin
          next_state = DONE;
        end else if (n_reg == 8'd0) begin
          // n in range 1-255, but safe guard: if 0, complete immediately
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      n_reg       <= 8'd0;
      i           <= 8'd0;
      even_count  <= 8'd0;
      odd_count   <= 8'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_reg      <= n;
            i          <= 8'd1;
            even_count <= 8'd0;
            odd_count  <= 8'd0;
          end
        end

        PROCESSING: begin
          if (n_reg == 8'd0) begin
            // Edge case, directly move to DONE via next_state
            done <= 1'b0;
          end else if (i <= n_reg) begin
            // Count on current i
            if (is_pal) begin
              if (is_even)
                even_count <= even_count + 8'd1;
              else
                odd_count  <= odd_count + 8'd1;
            end
            // Move to next i
            i <= i + 8'd1;
            done <= 1'b0;
          end else begin
            // Completed processing; DONE will be set in DONE state
            done <= 1'b0;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold counts; wait for start deassert then new start
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule