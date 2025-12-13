module sort_dict_by_val(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] size,
  input  [3:0] keys_in [0:3],
  input  [15:0] vals_in [0:3],
  output reg [3:0]  sorted_keys [0:3],
  output reg [15:0] sorted_vals [0:3],
  output reg done
);

  // Internal registers for working arrays
  reg [3:0]  keys [0:3];
  reg [15:0] vals [0:3];

  // Bubble sort indices/state
  reg [2:0] i; // up to 4
  reg [2:0] j; // up to 4
  reg sorting;

  // Swap temporaries
  reg [3:0]  tmp_key;
  reg [15:0] tmp_val;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      sorted_keys[0] <= 4'd0;
      sorted_keys[1] <= 4'd0;
      sorted_keys[2] <= 4'd0;
      sorted_keys[3] <= 4'd0;
      sorted_vals[0] <= 16'd0;
      sorted_vals[1] <= 16'd0;
      sorted_vals[2] <= 16'd0;
      sorted_vals[3] <= 16'd0;
      keys[0]        <= 4'd0;
      keys[1]        <= 4'd0;
      keys[2]        <= 4'd0;
      keys[3]        <= 4'd0;
      vals[0]        <= 16'd0;
      vals[1]        <= 16'd0;
      vals[2]        <= 16'd0;
      vals[3]        <= 16'd0;
      i              <= 3'd0;
      j              <= 3'd0;
      sorting        <= 1'b0;
      done           <= 1'b0;
    end else begin
      if (start && !sorting) begin
        // Start: load inputs and initialize
        done    <= 1'b0;
        sorting <= 1'b1;

        // Initialize active entries based on size
        keys[0] <= (size > 0) ? keys_in[0] : 4'd0;
        vals[0] <= (size > 0) ? vals_in[0] : 16'd0;

        keys[1] <= (size > 1) ? keys_in[1] : 4'd0;
        vals[1] <= (size > 1) ? vals_in[1] : 16'd0;

        keys[2] <= (size > 2) ? keys_in[2] : 4'd0;
        vals[2] <= (size > 2) ? vals_in[2] : 16'd0;

        keys[3] <= (size > 3) ? keys_in[3] : 4'd0;
        vals[3] <= (size > 3) ? vals_in[3] : 16'd0;

        // Initialize bubble sort indices
        i <= 3'd0;
        j <= 3'd0;
      end else if (sorting) begin
        // Perform one bubble compare-swap per cycle
        if (i < 3) begin
          if (j < (3 - i)) begin
            // Compare neighboring elements for descending order
            if (vals[j] < vals[j+1]) begin
              // Swap values
              tmp_val   <= vals[j];
              vals[j]   <= vals[j+1];
              vals[j+1] <= tmp_val;
              // Swap corresponding keys
              tmp_key   <= keys[j];
              keys[j]   <= keys[j+1];
              keys[j+1] <= tmp_key;
            end
            // Advance inner index
            j <= j + 3'd1;
          end else begin
            // End of inner loop, move to next outer pass
            j <= 3'd0;
            i <= i + 3'd1;
          end
        end else begin
          // Sorting complete
          sorting <= 1'b0;
          done    <= 1'b1;

          // Drive outputs with sorted results
          sorted_keys[0] <= keys[0];
          sorted_keys[1] <= keys[1];
          sorted_keys[2] <= keys[2];
          sorted_keys[3] <= keys[3];
          sorted_vals[0] <= vals[0];
          sorted_vals[1] <= vals[1];
          sorted_vals[2] <= vals[2];
          sorted_vals[3] <= vals[3];
        end
      end else begin
        // Idle state: keep done stable until next start
        done <= done;
      end
    end
  end

endmodule