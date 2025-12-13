module frequency_counter(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  data_in [0:15],
  input  logic [7:0]  query_key,
  output logic [7:0]  frequency_value,
  output logic        done
);

  // 256-entry frequency table, each 8 bits wide
  logic [7:0] freq_mem [0:255];

  // Counters and control
  logic [4:0]  cycle_cnt;     // 0..16
  logic        processing;    // indicates counting phase active

  // Simple FSM states
  typedef enum logic [1:0] {
    S_IDLE      = 2'b00,
    S_CLEAR     = 2'b01,
    S_COUNT     = 2'b10,
    S_DONE      = 2'b11
  } state_t;

  state_t state, next_state;

  // Next-state and control logic
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_CLEAR;
      end
      S_CLEAR: begin
        if (cycle_cnt == 5'd31) // finish clearing 0..31 (8 entries per cycle x 32 cycles = 256)
          next_state = S_COUNT;
      end
      S_COUNT: begin
        if (cycle_cnt == 5'd15) // 16 elements processed
          next_state = S_DONE;
      end
      S_DONE: begin
        // Stay in DONE until a new start is requested
        if (start)
          next_state = S_CLEAR;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      cycle_cnt  <= 5'd0;
      done       <= 1'b0;
      processing <= 1'b0;
      frequency_value <= 8'd0;
      // Clear frequency memory on reset
      integer i_reset;
      for (i_reset = 0; i_reset < 256; i_reset = i_reset + 1) begin
        freq_mem[i_reset] <= 8'd0;
      end
    end
    else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          processing <= 1'b0;
          cycle_cnt  <= 5'd0;
        end

        S_CLEAR: begin
          // Clear 8 entries per cycle using dual-port style (abstracted)
          // Addresses: 8*cycle_cnt .. 8*cycle_cnt+7
          integer j;
          for (j = 0; j < 8; j = j + 1) begin
            freq_mem[{cycle_cnt, 3'b000} + j] <= 8'd0;
          end

          if (cycle_cnt == 5'd31) begin
            cycle_cnt  <= 5'd0;
            processing <= 1'b1;
          end
          else begin
            cycle_cnt <= cycle_cnt + 5'd1;
          end
          done <= 1'b0;
        end

        S_COUNT: begin
          // Sequentially count one element per cycle
          // Use dual-port style: read-modify-write in one cycle (abstracted)
          logic [7:0] val;
          logic [7:0] cur_cnt;

          val     = data_in[cycle_cnt];
          cur_cnt = freq_mem[val];

          // Increment count, saturate at 255
          if (cur_cnt != 8'hFF)
            freq_mem[val] <= cur_cnt + 8'd1;
          else
            freq_mem[val] <= cur_cnt;

          if (cycle_cnt == 5'd15) begin
            cycle_cnt  <= 5'd0;
            processing <= 1'b0;
          end
          else begin
            cycle_cnt <= cycle_cnt + 5'd1;
          end
          done <= 1'b0;
        end

        S_DONE: begin
          done       <= 1'b1;
          processing <= 1'b0;
          cycle_cnt  <= 5'd0;
        end

        default: begin
          done       <= 1'b0;
          processing <= 1'b0;
          cycle_cnt  <= 5'd0;
        end
      endcase

      // Asynchronous-style query: frequency_value reflects freq_mem[query_key]
      // within a clocked process (combinational read modeled as sync for ASIC)
      frequency_value <= freq_mem[query_key];
    end
  end

endmodule