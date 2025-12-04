module zebra_partition(
  input clk,
  input rst_n,
  input start,
  input [15:0] s,
  input [3:0] str_len,
  output reg done,
  output reg valid,
  output reg [3:0] k,
  output reg [63:0] indices
);

  // FSM states
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam FINAL = 2'b10;

  reg [1:0] state, next_state;

  // position counter
  reg [4:0] pos;        // 0..16

  // subsequence masks and end-bit state
  reg [15:0] mask [0:3];
  reg       end_is_one [0:3];

  // flags for subsequence usage
  reg [1:0] used_count; // number of subsequences in use (0..4)

  // internal control
  reg error_flag;

  // utility: find indices
  integer i;
  reg [1:0] idx_zero_oldest;
  reg [1:0] idx_zero_new;
  reg [1:0] idx_one_oldest;
  reg       has_zero_ended;
  reg       has_one_ended;

  // current bit
  wire curr_bit = s[15 - pos];

  // combinational search for required subsequences
  always @(*) begin
    // defaults
    has_zero_ended = 1'b0;
    has_one_ended  = 1'b0;
    idx_zero_oldest = 2'd0;
    idx_one_oldest  = 2'd0;
    idx_zero_new    = used_count; // next new index if allowed

    // find oldest 0-ended subsequence (lower index = older)
    for (i = 0; i < used_count; i = i + 1) begin
      if (!end_is_one[i]) begin
        if (!has_zero_ended) begin
          has_zero_ended = 1'b1;
          idx_zero_oldest = i[1:0];
        end
      end
    end

    // find oldest 1-ended subsequence (for '0' case)
    for (i = 0; i < used_count; i = i + 1) begin
      if (end_is_one[i]) begin
        if (!has_one_ended) begin
          has_one_ended = 1'b1;
          idx_one_oldest = i[1:0];
        end
      end
    end
  end

  // FSM next state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN;
      end
      RUN: begin
        if (pos == str_len)
          next_state = FINAL;
      end
      FINAL: begin
        // done asserted one cycle; return to IDLE when start deasserted
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // sequential logic
  integer j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      pos        <= 5'd0;
      used_count <= 2'd0;
      error_flag <= 1'b0;
      done       <= 1'b0;
      valid      <= 1'b0;
      k          <= 4'd0;
      indices    <= 64'd0;
      for (j = 0; j < 4; j = j + 1) begin
        mask[j]       <= 16'd0;
        end_is_one[j] <= 1'b0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          valid      <= 1'b0;
          if (start) begin
            // initialize on start
            pos        <= 5'd0;
            used_count <= 2'd0;
            error_flag <= 1'b0;
            for (j = 0; j < 4; j = j + 1) begin
              mask[j]       <= 16'd0;
              end_is_one[j] <= 1'b0;
            end
          end
        end

        RUN: begin
          done  <= 1'b0;
          valid <= 1'b0;

          if (pos < str_len) begin
            // process current bit at position pos
            if (curr_bit == 1'b0) begin
              // '0': use oldest available '1'-ended subsequence or create new
              if (has_one_ended) begin
                // add to oldest 1-ended subsequence
                mask[idx_one_oldest][15 - pos] <= 1'b1;
                end_is_one[idx_one_oldest]     <= 1'b0;
              end else begin
                // create new subsequence if available
                if (used_count < 4) begin
                  mask[used_count]            <= 16'd0;
                  mask[used_count][15 - pos]  <= 1'b1;
                  end_is_one[used_count]      <= 1'b0;
                  used_count                  <= used_count + 1'b1;
                end else begin
                  // no space for new subsequence
                  error_flag <= 1'b1;
                end
              end
            end else begin
              // '1': must add to existing '0'-ended subsequence
              if (has_zero_ended) begin
                mask[idx_zero_oldest][15 - pos] <= 1'b1;
                end_is_one[idx_zero_oldest]     <= 1'b1;
              end else begin
                // no valid 0-ended subsequence
                error_flag <= 1'b1;
              end
            end

            // advance position
            pos <= pos + 1'b1;
          end
        end

        FINAL: begin
          // Evaluate validity and generate outputs;
          // this state is reached after pos == str_len
          // Compute k and check no subsequence ends with '1'
          done    <= 1'b1;
          valid   <= 1'b0;
          k       <= 4'd0;
          indices <= 64'd0;

          // Determine final k = used_count if all constraints satisfied
          // Check for ending with '1'
          if (!error_flag) begin
            // verify none end with '1'
            for (j = 0; j < used_count; j = j + 1) begin
              if (end_is_one[j]) begin
                error_flag <= 1'b1;
              end
            end
          end

          // Prepare outputs based on (possibly updated) error_flag next cycle
          // Use a second loop after potential updates
          if (!error_flag) begin
            k <= {2'b00, used_count};
            // pack indices: subseq0 -> [63:48], 1 -> [47:32], 2 -> [31:16], 3 -> [15:0]
            indices[63:48] <= (used_count > 0) ? mask[0] : 16'd0;
            indices[47:32] <= (used_count > 1) ? mask[1] : 16'd0;
            indices[31:16] <= (used_count > 2) ? mask[2] : 16'd0;
            indices[15:0]  <= (used_count > 3) ? mask[3] : 16'd0;
            valid          <= 1'b1;
          end else begin
            // invalid partition
            k       <= 4'd0;
            indices <= 64'd0;
            valid   <= 1'b0;
          end

          // stay in FINAL until start is low, then IDLE via next_state
        end

        default: begin
          // safety
          done       <= 1'b0;
          valid      <= 1'b0;
          pos        <= 5'd0;
          used_count <= 2'd0;
        end
      endcase
    end
  end

endmodule