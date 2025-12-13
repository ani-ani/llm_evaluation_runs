module flatten_unique_numbers(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic [7:0]        list_data [0:2][0:2],
  output logic [7:0]        unique_array [0:7],
  output logic [2:0]        unique_count,
  output logic              done
);

  // Internal registers
  logic [255:0] seen;          // one bit per 8-bit value
  logic [3:0]   idx;           // processing index 0..8
  logic [7:0]   current_val;
  logic         processing;

  // Flattened access to 3x3 input in row-major order
  function automatic [7:0] get_element(input logic [3:0] index);
    case (index)
      4'd0: get_element = list_data[0][0];
      4'd1: get_element = list_data[0][1];
      4'd2: get_element = list_data[0][2];
      4'd3: get_element = list_data[1][0];
      4'd4: get_element = list_data[1][1];
      4'd5: get_element = list_data[1][2];
      4'd6: get_element = list_data[2][0];
      4'd7: get_element = list_data[2][1];
      4'd8: get_element = list_data[2][2];
      default: get_element = 8'd0;
    endcase
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seen         <= 256'd0;
      unique_count <= 3'd0;
      done         <= 1'b0;
      idx          <= 4'd0;
      processing   <= 1'b0;
      unique_array[0] <= 8'd0;
      unique_array[1] <= 8'd0;
      unique_array[2] <= 8'd0;
      unique_array[3] <= 8'd0;
      unique_array[4] <= 8'd0;
      unique_array[5] <= 8'd0;
      unique_array[6] <= 8'd0;
      unique_array[7] <= 8'd0;
    end else begin
      // Default: deassert done unless explicitly set at end
      done <= 1'b0;

      if (start && !processing) begin
        // Initialize for new operation
        seen         <= 256'd0;
        unique_count <= 3'd0;
        idx          <= 4'd0;
        processing   <= 1'b1;
      end else if (processing) begin
        // Process current index (0..8)
        current_val = get_element(idx);

        if (!seen[current_val]) begin
          // Mark as seen and store in unique_array
          seen[current_val] <= 1'b1;
          if (unique_count < 3'd7) begin
            unique_array[unique_count] <= current_val;
          end
          unique_count <= unique_count + 3'd1;
        end

        // Advance index and check for completion
        if (idx == 4'd8) begin
          done       <= 1'b1;   // Assert done exactly after 9th element
          processing <= 1'b0;   // Stop processing until next start
        end
        idx <= idx + 4'd1;
      end
    end
  end

endmodule