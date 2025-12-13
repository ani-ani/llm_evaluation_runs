module sorted_array_kth_element(
  input              clk,
  input              rst_n,
  input              start,
  input      [2:0]   arr1_len,
  input      [2:0]   arr2_len,
  input      [9:0]   arr1 [0:7],
  input      [9:0]   arr2 [0:7],
  input      [3:0]   k_in,
  output reg [9:0]   kth_element,
  output reg         done,
  output reg         error
);

  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    COMPARE    = 3'd1,
    CHECK_ARR1 = 3'd2,
    CHECK_ARR2 = 3'd3,
    DONE       = 3'd4
  } state_t;

  state_t state, next_state;

  reg [2:0] i;               // index for arr1 (0-7)
  reg [2:0] j;               // index for arr2 (0-7)
  reg [4:0] count;           // up to 16
  reg [3:0] k_reg;           // latched k_in
  reg [2:0] arr1_len_reg;    // latched arr1_len
  reg [2:0] arr2_len_reg;    // latched arr2_len

  wire [4:0] total_len = arr1_len_reg + arr2_len_reg;

  // Sequential logic: state, counters, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      i            <= 3'd0;
      j            <= 3'd0;
      count        <= 5'd0;
      k_reg        <= 4'd0;
      arr1_len_reg <= 3'd0;
      arr2_len_reg <= 3'd0;
      kth_element  <= 10'd0;
      done         <= 1'b0;
      error        <= 1'b0;
    end else begin
      state <= next_state;

      // Default single-cycle outputs
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs and initialize
            i            <= 3'd0;
            j            <= 3'd0;
            count        <= 5'd0;
            k_reg        <= k_in;
            arr1_len_reg <= arr1_len;
            arr2_len_reg <= arr2_len;
            error        <= 1'b0;
            kth_element  <= 10'd0;
          end
        end

        COMPARE: begin
          // If k is invalid, nothing here; transition logic handles
          if (!error) begin
            // Select next smallest element from both arrays
            // assuming bounds checked in next_state logic
            if ((i < arr1_len_reg) && (j < arr2_len_reg)) begin
              if (arr1[i] <= arr2[j]) begin
                kth_element <= arr1[i];
                i <= i + 3'd1;
              end else begin
                kth_element <= arr2[j];
                j <= j + 3'd1;
              end
              count <= count + 5'd1;
            end
          end
        end

        CHECK_ARR1: begin
          if (!error && (i < arr1_len_reg)) begin
            kth_element <= arr1[i];
            i <= i + 3'd1;
            count <= count + 5'd1;
          end
        end

        CHECK_ARR2: begin
          if (!error && (j < arr2_len_reg)) begin
            kth_element <= arr2[j];
            j <= j + 3'd1;
            count <= count + 5'd1;
          end
        end

        DONE: begin
          done <= 1'b1; // pulse for one cycle
          // hold kth_element and error as already set
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          // Check for error condition on start
          if (k_in == 0 || (arr1_len + arr2_len) < k_in) begin
            next_state = DONE;
          end else begin
            next_state = COMPARE;
          end
        end
      end

      COMPARE: begin
        // If k invalid, go to DONE (error will be set in comb block below)
        if (error) begin
          next_state = DONE;
        end else begin
          // Termination: if we have selected k elements
          if (count + 1 == k_reg) begin
            // Next selected element in this state will be k-th
            next_state = DONE;
          end else begin
            // Decide which path based on bounds
            if ((i >= arr1_len_reg) && (j < arr2_len_reg)) begin
              next_state = CHECK_ARR2;
            end else if ((j >= arr2_len_reg) && (i < arr1_len_reg)) begin
              next_state = CHECK_ARR1;
            end else if ((i < arr1_len_reg) && (j < arr2_len_reg)) begin
              next_state = COMPARE;
            end else begin
              // No more elements but count < k_reg -> error
              next_state = DONE;
            end
          end
        end
      end

      CHECK_ARR1: begin
        if (error) begin
          next_state = DONE;
        end else if (count + 1 == k_reg) begin
          next_state = DONE;
        end else if (i < arr1_len_reg) begin
          next_state = CHECK_ARR1;
        end else begin
          // No more elements
          next_state = DONE;
        end
      end

      CHECK_ARR2: begin
        if (error) begin
          next_state = DONE;
        end else if (count + 1 == k_reg) begin
          next_state = DONE;
        end else if (j < arr2_len_reg) begin
          next_state = CHECK_ARR2;
        end else begin
          // No more elements
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait for next start to restart
        if (start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combinational error generation (based on latched values when running, and direct on start in IDLE)
  always @(*) begin
    // Default: keep current error unless in IDLE/start decision
    // Implement combinational view consistent with state
    if (state == IDLE) begin
      if (start) begin
        if (k_in == 0 || (arr1_len + arr2_len) < k_in)
          error = 1'b1;
        else
          error = 1'b0;
      end
    end else begin
      // While running, error if remaining elements are insufficient
      if (!error) begin
        if (k_reg == 0 || total_len < k_reg)
          error = 1'b1;
        else if (count < k_reg && (i >= arr1_len_reg) && (j >= arr2_len_reg))
          error = 1'b1;
      end
    end
  end

endmodule