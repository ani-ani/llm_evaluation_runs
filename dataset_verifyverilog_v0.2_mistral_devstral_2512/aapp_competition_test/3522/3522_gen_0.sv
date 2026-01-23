module chip_allocator (
  input clk,
  input rst_n,
  input start,
  input [5:0] total_batteries,
  input [7:0] battery_powers [0:11],
  output reg [7:0] min_difference,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SORTING,
    PAIRING,
    FIND_MAX,
    DONE
  } state_t;

  state_t state;
  reg [7:0] sorted_powers [0:11];
  reg [7:0] current_diff;
  reg [7:0] max_diff;
  reg [3:0] sort_pass;
  reg [3:0] sort_index;
  reg [3:0] pair_index;
  reg [3:0] cycle_count;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_difference <= 0;
      done <= 0;
      sort_pass <= 0;
      sort_index <= 0;
      pair_index <= 0;
      cycle_count <= 0;
      current_diff <= 0;
      max_diff <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORTING;
            // Initialize sorted array
            for (int i = 0; i < 12; i++) begin
              sorted_powers[i] <= battery_powers[i];
            end
            sort_pass <= 0;
            sort_index <= 0;
          end
        end

        SORTING: begin
          // Bubble sort implementation
          if (sort_pass < 11) begin
            if (sort_index < 11 - sort_pass) begin
              if (sorted_powers[sort_index] > sorted_powers[sort_index + 1]) begin
                // Swap
                reg [7:0] temp;
                temp = sorted_powers[sort_index];
                sorted_powers[sort_index] <= sorted_powers[sort_index + 1];
                sorted_powers[sort_index + 1] <= temp;
              end
              sort_index <= sort_index + 1;
            end else begin
              sort_index <= 0;
              sort_pass <= sort_pass + 1;
            end
          end else begin
            state <= PAIRING;
            pair_index <= 0;
            max_diff <= 0;
          end
        end

        PAIRING: begin
          if (pair_index < total_batteries - 1) begin
            if (pair_index % 2 == 0) begin
              current_diff <= sorted_powers[pair_index + 1] - sorted_powers[pair_index];
              if (current_diff > max_diff) begin
                max_diff <= current_diff;
              end
            end
            pair_index <= pair_index + 1;
          end else begin
            state <= FIND_MAX;
          end
        end

        FIND_MAX: begin
          state <= DONE;
          min_difference <= max_diff;
          done <= 1;
        end

        DONE: begin
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule