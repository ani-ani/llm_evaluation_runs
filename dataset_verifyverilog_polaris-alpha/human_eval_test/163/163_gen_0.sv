module even_digit_filter(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  a,
  input  logic [7:0]  b,
  output logic [3:0][7:0] result_array,
  output logic [1:0]  valid_count,
  output logic        done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t        state, next_state;
  logic [7:0]    min_val, max_val;
  logic [7:0]    cur_val;
  logic [1:0]    count_reg;
  logic [3:0][7:0] buffer;

  // Combinational min/max
  always_comb begin
    if (a <= b) begin
      min_val = a;
      max_val = b;
    end else begin
      min_val = b;
      max_val = a;
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN;
      end
      RUN: begin
        if (cur_val == max_val)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      cur_val     <= 8'd0;
      count_reg   <= 2'd0;
      buffer[0]   <= 8'd0;
      buffer[1]   <= 8'd0;
      buffer[2]   <= 8'd0;
      buffer[3]   <= 8'd0;
      done        <= 1'b0;
      result_array<= '{default:8'd0};
      valid_count <= 2'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for new run
            cur_val   <= min_val;
            count_reg <= 2'd0;
            buffer[0] <= 8'd0;
            buffer[1] <= 8'd0;
            buffer[2] <= 8'd0;
            buffer[3] <= 8'd0;
          end
        end

        RUN: begin
          // Check conditions for current value
          if ((cur_val <= 8'd9) && (cur_val[0] == 1'b0)) begin
            if (count_reg < 2'd4) begin
              buffer[count_reg] <= cur_val;
              count_reg         <= count_reg + 2'd1;
            end
          end

          // Advance cur_val or transition handled in next_state
          if (cur_val != max_val)
            cur_val <= cur_val + 8'd1;
        end

        DONE: begin
          done        <= 1'b1;
          result_array<= buffer;
          valid_count <= count_reg;
          // Wait here until start is deasserted, then IDLE via next_state
        end

        default: begin
          // Safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule