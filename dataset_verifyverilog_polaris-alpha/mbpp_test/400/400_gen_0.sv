module unique_tuples (
  input  clk,
  input  rst_n,
  input  start,
  input  [31:0] data,
  output reg [2:0] unique_count,
  output reg      done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    STEP0 = 3'd1,
    STEP1 = 3'd2,
    STEP2 = 3'd3,
    STEP3 = 3'd4,
    DONE  = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal storage for up to 4 unique sorted tuples
  reg [3:0] uniq_a [0:3];
  reg [3:0] uniq_b [0:3];
  reg [2:0] uniq_count_next;

  // Extracted tuple values for current step
  reg [3:0] cur_a, cur_b;
  reg [3:0] s_min, s_max;

  // Combinational: select current tuple based on state
  always @(*) begin
    cur_a = 4'd0;
    cur_b = 4'd0;
    case (state)
      STEP0: begin
        cur_a = data[31:28];
        cur_b = data[27:24];
      end
      STEP1: begin
        cur_a = data[23:20];
        cur_b = data[19:16];
      end
      STEP2: begin
        cur_a = data[15:12];
        cur_b = data[11:8];
      end
      STEP3: begin
        cur_a = data[7:4];
        cur_b = data[3:0];
      end
      default: begin
        cur_a = 4'd0;
        cur_b = 4'd0;
      end
    endcase
  end

  // Combinational: sort current tuple into (min,max)
  always @(*) begin
    if (cur_a <= cur_b) begin
      s_min = cur_a;
      s_max = cur_b;
    end else begin
      s_min = cur_b;
      s_max = cur_a;
    end
  end

  // Combinational: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:  begin
        if (start)
          next_state = STEP0;
      end
      STEP0: next_state = STEP1;
      STEP1: next_state = STEP2;
      STEP2: next_state = STEP3;
      STEP3: next_state = DONE;
      DONE:  next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Combinational: unique_count_next calculation & tuple insertion
  integer i;
  reg found;
  always @(*) begin
    // Default: hold current count
    uniq_count_next = unique_count;
    found = 1'b0;

    case (state)
      STEP0, STEP1, STEP2, STEP3: begin
        // Check if (s_min,s_max) already stored
        for (i = 0; i < unique_count; i = i + 1) begin
          if ((uniq_a[i] == s_min) && (uniq_b[i] == s_max)) begin
            found = 1'b1;
          end
        end
        // If not found and space available, increment count
        if (!found && (unique_count < 4)) begin
          uniq_count_next = unique_count + 3'd1;
        end
      end
      default: begin
        uniq_count_next = unique_count;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      unique_count  <= 3'd0;
      done          <= 1'b0;
      uniq_a[0]     <= 4'd0;
      uniq_a[1]     <= 4'd0;
      uniq_a[2]     <= 4'd0;
      uniq_a[3]     <= 4'd0;
      uniq_b[0]     <= 4'd0;
      uniq_b[1]     <= 4'd0;
      uniq_b[2]     <= 4'd0;
      uniq_b[3]     <= 4'd0;
    end else begin
      state <= next_state;

      // Default done low, assert only in DONE state for one cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Clear storage and count at start
            unique_count <= 3'd0;
            uniq_a[0]    <= 4'd0;
            uniq_a[1]    <= 4'd0;
            uniq_a[2]    <= 4'd0;
            uniq_a[3]    <= 4'd0;
            uniq_b[0]    <= 4'd0;
            uniq_b[1]    <= 4'd0;
            uniq_b[2]    <= 4'd0;
            uniq_b[3]    <= 4'd0;
          end
        end

        STEP0, STEP1, STEP2, STEP3: begin
          // If new unique tuple, append at index unique_count
          if ((uniq_count_next > unique_count) && (unique_count < 4)) begin
            uniq_a[unique_count] <= s_min;
            uniq_b[unique_count] <= s_max;
          end
          unique_count <= uniq_count_next;
        end

        DONE: begin
          // unique_count already correct; assert done for this cycle
          done <= 1'b1;
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule