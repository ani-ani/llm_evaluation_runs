module second_smallest (
  input clk,
  input rst_n,
  input start,
  input [15:0] numbers[0:7],
  output reg [15:0] result,
  output reg valid,
  output reg done
);

  typedef enum logic [1:0] {IDLE, REMOVE_DUPS, SORT, OUTPUT} state_t;
  state_t current_state, next_state;

  reg [3:0] i_counter;
  reg [3:0] unique_count;
  reg [3:0] pass_count;
  reg [15:0] unique_array[0:7];
  reg [15:0] sorted_array[0:7];
  wire duplicate_found;

  always_comb begin
    duplicate_found = 1'b0;
    for (int j=0; j<unique_count; j=j+1) begin
      if (numbers[i_counter] == unique_array[j]) begin
        duplicate_found = 1'b1;
      end
    end
  end

  reg [15:0] next_sorted_array[0:7];
  reg swapped;
  always_comb begin
    swapped = 1'b0;
    next_sorted_array = sorted_array;
    for (int i=0; i < (unique_count - 1); i=i+1) begin
      if (sorted_array[i] > sorted_array[i+1]) begin
        next_sorted_array[i] = sorted_array[i+1];
        next_sorted_array[i+1] = sorted_array[i];
        swapped = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 16'h0000;
      valid <= 1'b0;
      done <= 1'b0;
      i_counter <= 4'h0;
      unique_count <= 4'h0;
      pass_count <= 4'h0;
      for (int i=0; i<8; i=i+1) begin
        unique_array[i] <= 16'h0000;
        sorted_array[i] <= 16'h0000;
      end
    end else begin
      current_state <= next_state;
      done <= (current_state == OUTPUT);

      case (current_state)
        IDLE: begin
          result <= 16'h0000;
          valid <= 1'b0;
          if (start) begin
            next_state <= REMOVE_DUPS;
            i_counter <= 4'h0;
            unique_count <= 4'h0;
          end else begin
            next_state <= IDLE;
          end
        end

        REMOVE_DUPS: begin
          if (i_counter < 8) begin
            if (!duplicate_found) begin
              unique_array[unique_count] <= numbers[i_counter];
              unique_count <= unique_count + 1;
            end
            i_counter <= i_counter + 1;
            next_state <= REMOVE_DUPS;
          end else begin
            for (int i=0; i<8; i=i+1) begin
              sorted_array[i] <= unique_array[i];
            end
            if (unique_count >= 2) begin
              next_state <= SORT;
              pass_count <= 4'h0;
            end else begin
              next_state <= OUTPUT;
            end
          end
        end

        SORT: begin
          if (pass_count < unique_count - 1) begin
            sorted_array <= next_sorted_array;
            pass_count <= pass_count + 1;
            next_state <= SORT;
          end else begin
            next_state <= OUTPUT;
          end
        end

        OUTPUT: begin
          if (unique_count >= 2) begin
            result <= sorted_array[1];
            valid <= 1'b1;
          end else begin
            result <= 16'h0000;
            valid <= 1'b0;
          end
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

endmodule