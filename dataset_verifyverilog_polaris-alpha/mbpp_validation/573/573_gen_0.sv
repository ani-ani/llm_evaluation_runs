module unique_product(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] data_in,
  input        data_valid,
  output reg [31:0] product,
  output reg       done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam COLLECT   = 2'b01;
  localparam CALCULATE = 2'b10;
  localparam DONE      = 2'b11;

  reg [1:0]  state, next_state;

  // Storage for up to 8 unique numbers
  reg [3:0] unique_vals [0:7];
  reg [2:0] unique_count; // 0..8

  integer i;

  // Asynchronous reset, synchronous state and storage updates
  always @(negedge rst_n or posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      unique_count <= 3'd0;
      product      <= 32'd0;
      done         <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        unique_vals[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done         <= 1'b0;
          product      <= 32'd0;
          unique_count <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            unique_vals[i] <= 4'd0;
          end
        end

        COLLECT: begin
          done <= 1'b0;
          if (data_valid) begin
            // Check uniqueness
            reg seen;
            seen = 1'b0;
            for (i = 0; i < unique_count; i = i + 1) begin
              if (unique_vals[i] == data_in)
                seen = 1'b1;
            end
            // Store if unique and capacity not exceeded
            if (!seen && (unique_count < 3'd8)) begin
              unique_vals[unique_count] <= data_in;
              unique_count             <= unique_count + 3'd1;
            end
          end
        end

        CALCULATE: begin
          // Compute product of stored unique values
          reg [31:0] prod_tmp;
          prod_tmp = 32'd1;
          for (i = 0; i < unique_count; i = i + 1) begin
            prod_tmp = prod_tmp * unique_vals[i];
          end
          product <= prod_tmp;
          done    <= 1'b0;
        end

        DONE: begin
          // Assert done for one cycle
          done <= 1'b1;
        end

        default: begin
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
          next_state = COLLECT;
      end

      COLLECT: begin
        // Transition to CALCULATE one cycle after last valid
        // Here we assume end of input when data_valid is low
        // and start has been deasserted (simple protocol)
        if (!data_valid)
          next_state = CALCULATE;
      end

      CALCULATE: begin
        // One cycle used for calculation
        next_state = DONE;
      end

      DONE: begin
        // Hold done for one cycle, then go back to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule