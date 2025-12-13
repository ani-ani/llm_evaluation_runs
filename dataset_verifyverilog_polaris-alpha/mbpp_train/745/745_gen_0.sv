module divisible_checker(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [7:0]  start_num,
  input  wire [7:0]  end_num,
  output reg  [7:0]  results [0:15],
  output reg  [4:0]  count,
  output reg         done
);

  typedef enum logic [1:0] {
    IDLE         = 2'b00,
    PROCESSING   = 2'b01,
    CHECK_DIGITS = 2'b10,
    DONE         = 2'b11
  } state_t;

  state_t state, next_state;

  reg [7:0] current_num;
  reg [7:0] temp_num;
  reg       valid_flag;
  reg [1:0] digit_stage;
  reg [3:0] result_index;

  // Extracted digits
  reg [3:0] d1, d2, d3; // ones, tens, hundreds

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      current_num  <= 8'd0;
      temp_num     <= 8'd0;
      valid_flag   <= 1'b0;
      digit_stage  <= 2'd0;
      result_index <= 4'd0;
      count        <= 5'd0;
      done         <= 1'b0;
      d1           <= 4'd0;
      d2           <= 4'd0;
      d3           <= 4'd0;
      // Clear results
      results[0]   <= 8'd0;
      results[1]   <= 8'd0;
      results[2]   <= 8'd0;
      results[3]   <= 8'd0;
      results[4]   <= 8'd0;
      results[5]   <= 8'd0;
      results[6]   <= 8'd0;
      results[7]   <= 8'd0;
      results[8]   <= 8'd0;
      results[9]   <= 8'd0;
      results[10]  <= 8'd0;
      results[11]  <= 8'd0;
      results[12]  <= 8'd0;
      results[13]  <= 8'd0;
      results[14]  <= 8'd0;
      results[15]  <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for new run
            current_num  <= start_num;
            temp_num     <= start_num;
            valid_flag   <= 1'b1; // assume valid until proven otherwise
            digit_stage  <= 2'd0;
            result_index <= 4'd0;
            count        <= 5'd0;
            // Clear results
            results[0]   <= 8'd0;
            results[1]   <= 8'd0;
            results[2]   <= 8'd0;
            results[3]   <= 8'd0;
            results[4]   <= 8'd0;
            results[5]   <= 8'd0;
            results[6]   <= 8'd0;
            results[7]   <= 8'd0;
            results[8]   <= 8'd0;
            results[9]   <= 8'd0;
            results[10]  <= 8'd0;
            results[11]  <= 8'd0;
            results[12]  <= 8'd0;
            results[13]  <= 8'd0;
            results[14]  <= 8'd0;
            results[15]  <= 8'd0;
          end
        end

        PROCESSING: begin
          // Begin digit extraction for current_num
          temp_num    <= current_num;
          digit_stage <= 2'd0;
          valid_flag  <= 1'b1; // reset for this number
        end

        CHECK_DIGITS: begin
          case (digit_stage)
            2'd0: begin
              // Extract ones digit
              d1        <= temp_num % 10;
              temp_num  <= temp_num / 10;
              digit_stage <= 2'd1;
            end

            2'd1: begin
              // Check ones digit
              if (d1 != 0 && (current_num % d1) != 0)
                valid_flag <= 1'b0;

              if (temp_num != 0) begin
                d2        <= temp_num % 10;
                temp_num  <= temp_num / 10;
                digit_stage <= 2'd2;
              end else begin
                // No more digits, move on
                digit_stage <= 2'd3;
              end
            end

            2'd2: begin
              // Check tens digit
              if (d2 != 0 && (current_num % d2) != 0)
                valid_flag <= 1'b0;

              if (temp_num != 0) begin
                d3          <= temp_num % 10;
                temp_num    <= temp_num / 10;
                // Check hundreds digit immediately next
                // Move to final stage
                digit_stage <= 2'd3;
              end else begin
                digit_stage <= 2'd3;
              end
            end

            2'd3: begin
              // Check hundreds digit if applicable
              if (d3 != 0 && (current_num % d3) != 0)
                valid_flag <= 1'b0;

              // After all digits checked, store result if valid
              if (valid_flag && result_index < 4'd16) begin
                results[result_index] <= current_num;
                result_index          <= result_index + 4'd1;
                count                 <= count + 5'd1;
              end

              // Move to next number or finish
              if (current_num >= end_num) begin
                done <= 1'b1;
              end else begin
                current_num <= current_num + 8'd1;
              end
            end

            default: begin
              digit_stage <= 2'd0;
            end
          endcase
        end

        DONE: begin
          // Hold done high until next start or reset
          done <= 1'b1;
          if (start) begin
            // Prepare for new run on next cycle via IDLE -> PROCESSING
            done <= 1'b0;
          end
        end

        default: begin
          // Safety defaults
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        next_state = CHECK_DIGITS;
      end

      CHECK_DIGITS: begin
        if (digit_stage == 2'd3) begin
          if ((current_num >= end_num) && valid_flag) begin
            // After handling last number, go to DONE
            next_state = DONE;
          end else if ((current_num >= end_num) && !valid_flag) begin
            next_state = DONE;
          end else begin
            // More numbers to process
            next_state = PROCESSING;
          end
        end else begin
          next_state = CHECK_DIGITS;
        end
      end

      DONE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = DONE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule