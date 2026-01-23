module max_product_seq (
  input clk,
  input rst_n,
  input start,
  input [2:0] arr_len,
  input [31:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  // Internal registers
  state_t state;
  reg [31:0] mpis [0:7];
  reg [2:0] i, j;
  reg [63:0] current_prod;
  reg [31:0] max_val;
  reg [31:0] arr [0:7];

  // Assign input array to internal array
  always @(*) begin
    arr[0] = arr_0;
    arr[1] = arr_1;
    arr[2] = arr_2;
    arr[3] = arr_3;
    arr[4] = arr_4;
    arr[5] = arr_5;
    arr[6] = arr_6;
    arr[7] = arr_7;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      i <= 0;
      j <= 0;
      current_prod <= 0;
      max_val <= 0;
      for (int k = 0; k < 8; k++) begin
        mpis[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            done <= 0;
            // Initialize mpis with array values
            for (int k = 0; k < 8; k++) begin
              mpis[k] <= arr[k];
            end
            i <= 0;
            j <= 0;
            current_prod <= 0;
            max_val <= 0;
          end
        end
        COMPUTE: begin
          if (i < arr_len) begin
            if (j == 0) begin
              current_prod <= $signed(arr[i]);
              j <= i + 1;
            end else if (j < arr_len) begin
              if ($signed(arr[j-1]) > $signed(arr[j])) begin
                j <= i + 1;
                i <= i + 1;
              end else begin
                current_prod <= $signed(current_prod) * $signed(arr[j]);
                if ($signed(current_prod) > $signed(mpis[j])) begin
                  mpis[j] <= current_prod[31:0];
                end
                j <= j + 1;
              end
            end else begin
              i <= i + 1;
              j <= 0;
            end
          end else begin
            // Find maximum value in mpis
            max_val <= mpis[0];
            for (int k = 1; k < 8; k++) begin
              if ($signed(mpis[k]) > $signed(max_val)) begin
                max_val <= mpis[k];
              end
            end
            state <= DONE;
          end
        end
        DONE: begin
          result <= max_val;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule