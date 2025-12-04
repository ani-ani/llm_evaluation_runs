module garbage_bags(
  input clk,
  input rst_n,
  input start,
  input [15:0] k,
  input [15:0] days_data [0:15],
  input [3:0] n,
  output reg [31:0] total_bags,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESSING  = 2'b01,
    DONE_STATE  = 2'b10
  } state_t;

  state_t state, next_state;

  reg [3:0]  day_counter;
  reg [31:0] leftover;
  reg [31:0] current_total;
  reg [31:0] bags_add;

  // Combinational next-state and datapath calculations
  always @* begin
    next_state   = state;
    current_total = 32'd0;
    bags_add      = 32'd0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Default: keep processing until last day handled
        next_state = PROCESSING;

        // Compute current_total only when within n days
        if (day_counter < n) begin
          current_total = leftover + days_data[day_counter];

          if (k != 0) begin
            // Add full bags from division
            bags_add = current_total / k;
          end
        end

        // Move to DONE after finishing the last required day
        if (day_counter >= n) begin
          next_state = DONE_STATE;
        end
      end

      DONE_STATE: begin
        // Stay in DONE until next start
        if (start) begin
          next_state = PROCESSING;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential state, counters, and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      total_bags  <= 32'd0;
      leftover    <= 32'd0;
      day_counter <= 4'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            total_bags  <= 32'd0;
            leftover    <= 32'd0;
            day_counter <= 4'd0;
          end
        end

        PROCESSING: begin
          done <= 1'b0;

          if (day_counter < n) begin
            // Perform operations for the current day
            if (k != 0) begin
              // Use precomputed current_total and bags_add from combinational logic
              total_bags <= total_bags + bags_add;

              // Update leftover based on modulo
              if (k != 0)
                leftover <= (leftover + days_data[day_counter]) % k;

              // Apply special rules
              // Rule f: If current_total < k and leftover != 0, add 1 bag and reset leftover
              if ((leftover + days_data[day_counter]) < k && ((leftover + days_data[day_counter]) != 0)) begin
                total_bags <= total_bags + bags_add + 32'd1;
                leftover   <= 32'd0;
              end else begin
                // Rule e: If on last day (day_counter == n-1), and leftover != 0, add 1 bag
                if (day_counter == (n - 1) && (((leftover + days_data[day_counter]) % k) != 0)) begin
                  total_bags <= total_bags + bags_add + 32'd1;
                end
              end
            end

            day_counter <= day_counter + 4'd1;
          end else begin
            // When day_counter reaches n, transition to DONE_STATE (via next_state)
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          // Hold total_bags, leftover, day_counter until new start
          if (start) begin
            done        <= 1'b0;
            total_bags  <= 32'd0;
            leftover    <= 32'd0;
            day_counter <= 4'd0;
          end
        end

        default: begin
          done        <= 1'b0;
          total_bags  <= 32'd0;
          leftover    <= 32'd0;
          day_counter <= 4'd0;
        end
      endcase
    end
  end

endmodule