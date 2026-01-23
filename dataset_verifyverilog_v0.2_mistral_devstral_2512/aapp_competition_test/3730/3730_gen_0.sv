module max_strictly_increasing_subsegment (
  input clk,
  input rst_n,
  input start,
  input [4:0] index_in,
  input [31:0] value_in,
  output reg [4:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [4:0] load_counter;
  reg [4:0] compute_counter;
  reg [31:0] array [0:15];
  reg [4:0] left [0:15];
  reg [4:0] right [0:15];
  reg [4:0] max_len;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_counter <= 0;
      compute_counter <= 0;
      result <= 0;
      done <= 0;
      max_len <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            load_counter <= 0;
          end
        end
        LOAD: begin
          if (load_counter < 16) begin
            array[index_in] <= value_in;
            load_counter <= load_counter + 1;
          end else begin
            state <= COMPUTE;
            compute_counter <= 0;
          end
        end
        COMPUTE: begin
          if (compute_counter < 16) begin
            // Calculate left array
            if (compute_counter == 0) begin
              left[0] <= 1;
            end else begin
              if (array[compute_counter] > array[compute_counter - 1]) begin
                left[compute_counter] <= left[compute_counter - 1] + 1;
              end else begin
                left[compute_counter] <= 1;
              end
            end
            compute_counter <= compute_counter + 1;
          end else if (compute_counter < 32) begin
            // Calculate right array
            if (compute_counter == 16) begin
              right[15] <= 1;
            end else begin
              if (array[31 - compute_counter] > array[32 - compute_counter]) begin
                right[31 - compute_counter] <= right[32 - compute_counter] + 1;
              end else begin
                right[31 - compute_counter] <= 1;
              end
            end
            compute_counter <= compute_counter + 1;
          end else begin
            // Calculate max_len
            max_len <= 1;
            for (int i = 0; i < 16; i = i + 1) begin
              if (left[i] > max_len) begin
                max_len <= left[i];
              end
              if (right[i] > max_len) begin
                max_len <= right[i];
              end
            end
            // Check for possible merges
            for (int i = 1; i < 15; i = i + 1) begin
              if (array[i+1] - array[i-1] > 1) begin
                if (left[i-1] + 1 + right[i+1] > max_len) begin
                  max_len <= left[i-1] + 1 + right[i+1];
                end
              end else begin
                if (left[i-1] + 1 > max_len) begin
                  max_len <= left[i-1] + 1;
                end
                if (right[i+1] + 1 > max_len) begin
                  max_len <= right[i+1] + 1;
                end
              end
            end
            result <= max_len;
            state <= DONE;
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule