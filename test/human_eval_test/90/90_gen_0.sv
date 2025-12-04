module next_smallest (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [7:0]  valid_mask,
  input  wire [7:0]  data0,
  input  wire [7:0]  data1,
  input  wire [7:0]  data2,
  input  wire [7:0]  data3,
  input  wire [7:0]  data4,
  input  wire [7:0]  data5,
  input  wire [7:0]  data6,
  input  wire [7:0]  data7,
  output reg  [7:0]  second_smallest,
  output reg         found,
  output reg         done
);

  // State encoding
  typedef enum logic [3:0] {
    IDLE       = 4'd0,
    COMPARE_0  = 4'd1,
    COMPARE_1  = 4'd2,
    COMPARE_2  = 4'd3,
    COMPARE_3  = 4'd4,
    COMPARE_4  = 4'd5,
    COMPARE_5  = 4'd6,
    COMPARE_6  = 4'd7,
    COMPARE_7  = 4'd8,
    FINISH     = 4'd9
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg signed [7:0] min_val;
  reg signed [7:0] second_min;
  reg        [3:0] idx;
  reg        [3:0] valid_count;
  reg              any_valid;

  // Data mux based on idx
  reg signed [7:0] cur_data;
  reg              cur_valid;

  always @(*) begin
    case (idx)
      4'd0: begin cur_data = data0; cur_valid = valid_mask[0]; end
      4'd1: begin cur_data = data1; cur_valid = valid_mask[1]; end
      4'd2: begin cur_data = data2; cur_valid = valid_mask[2]; end
      4'd3: begin cur_data = data3; cur_valid = valid_mask[3]; end
      4'd4: begin cur_data = data4; cur_valid = valid_mask[4]; end
      4'd5: begin cur_data = data5; cur_valid = valid_mask[5]; end
      4'd6: begin cur_data = data6; cur_valid = valid_mask[6]; end
      4'd7: begin cur_data = data7; cur_valid = valid_mask[7]; end
      default: begin cur_data = 8'sd0; cur_valid = 1'b0; end
    endcase
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPARE_0;
        else
          next_state = IDLE;
      end

      COMPARE_0: next_state = COMPARE_1;
      COMPARE_1: next_state = COMPARE_2;
      COMPARE_2: next_state = COMPARE_3;
      COMPARE_3: next_state = COMPARE_4;
      COMPARE_4: next_state = COMPARE_5;
      COMPARE_5: next_state = COMPARE_6;
      COMPARE_6: next_state = COMPARE_7;
      COMPARE_7: next_state = FINISH;

      FINISH: begin
        // done is pulsed for one cycle; then return to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      min_val         <= 8'sh7F;
      second_min      <= 8'sh7F;
      valid_count     <= 4'd0;
      any_valid       <= 1'b0;
      idx             <= 4'd0;
      second_smallest <= 8'h00;
      found           <= 1'b0;
      done            <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize search
            min_val     <= 8'sh7F;
            second_min  <= 8'sh7F;
            valid_count <= 4'd0;
            any_valid   <= 1'b0;
            idx         <= 4'd0;
            // Keep outputs cleared until FINISH
            second_smallest <= 8'h00;
            found           <= 1'b0;
          end
        end

        COMPARE_0, COMPARE_1, COMPARE_2, COMPARE_3,
        COMPARE_4, COMPARE_5, COMPARE_6, COMPARE_7: begin
          // Process current index
          if (cur_valid) begin
            any_valid   <= 1'b1;
            valid_count <= valid_count + 4'd1;
            // Update min and second_min for signed values
            if (cur_data < min_val) begin
              second_min <= min_val;
              min_val    <= cur_data;
            end else if ((cur_data < second_min) && (cur_data != min_val)) begin
              second_min <= cur_data;
            end
          end
          // Increment index for next cycle
          idx <= idx + 4'd1;
        end

        FINISH: begin
          // Evaluate result based on collected mins
          // Conditions for found = 1:
          // - At least two valid values
          // - second_min updated (!= 7F)
          // - second_min distinct from min_val
          if ((valid_count >= 4'd2) && (second_min != 8'sh7F) && (min_val != second_min)) begin
            found           <= 1'b1;
            second_smallest <= second_min[7:0];
          end else begin
            found           <= 1'b0;
            second_smallest <= 8'h00;
          end
          done <= 1'b1; // pulse done for this cycle
        end

        default: begin
          // Should not occur; keep safe defaults
        end
      endcase
    end
  end

endmodule