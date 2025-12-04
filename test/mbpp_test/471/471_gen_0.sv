module array_modulo_product (
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] n,
  input  [7:0] data,
  input        data_valid,
  output reg [7:0] result,
  output reg       done
);

  reg [7:0] product;
  reg [3:0] count;        // Counts data_valid pulses, up to 8
  reg       busy;         // Indicates active computation
  reg       last_dv;      // Last data_valid sampled
  reg [1:0] post_cnt;     // Counts 2 cycles after last valid
  reg       last_phase;   // Indicates post-processing phase active

  wire [7:0] data_mod_n;
  wire [15:0] mult_full;
  wire [7:0] mult_mod_n;

  // Compute data % n (n > 0 as per spec)
  assign data_mod_n = (data >= n) ? (data % n) : data;

  // Multiply current product by (data % n)
  assign mult_full = product * data_mod_n;

  // Compute (product * (data % n)) % n
  assign mult_mod_n = (mult_full >= n) ? (mult_full % n) : mult_full[7:0];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      product    <= 8'd1;
      result     <= 8'd0;
      done       <= 1'b0;
      count      <= 4'd0;
      busy       <= 1'b0;
      last_dv    <= 1'b0;
      post_cnt   <= 2'd0;
      last_phase <= 1'b0;
    end else begin
      // Track rising edges of data_valid
      last_dv <= data_valid;

      // Default
      done <= 1'b0;

      // Start condition
      if (start) begin
        product    <= 8'd1;
        count      <= 4'd0;
        busy       <= 1'b1;
        post_cnt   <= 2'd0;
        last_phase <= 1'b0;
      end else if (busy) begin
        // Active computation phase

        // Process at most 8 elements
        if (data_valid && !last_dv && (count < 4'd8)) begin
          // On each new valid element: update product modulo n
          product <= (n != 8'd0) ? mult_mod_n : 8'd0;
          count   <= count + 4'd1;
          post_cnt <= 2'd0;
          last_phase <= 1'b0;
        end else begin
          // No new data_valid edge this cycle
          if (!data_valid && last_dv && (count != 4'd0)) begin
            // Detect end of last element sequence and start 2-cycle post phase
            last_phase <= 1'b1;
            post_cnt   <= 2'd0;
          end else if (last_phase) begin
            // Post-processing cycles after last element
            post_cnt <= post_cnt + 2'd1;
            if (post_cnt == 2'd1) begin
              // After 2 cycles from last element: produce result
              result <= (n != 8'd0) ? (product % n) : product;
              done   <= 1'b1;
              busy   <= 1'b0;
              last_phase <= 1'b0;
            end
          end
        end
      end
    end
  end

endmodule
