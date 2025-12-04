module love_potion_counter (
  input logic clk,
  input logic rst_n,
  input logic start,
  input logic signed [7:0] a [0:7],
  input logic signed [7:0] k,
  output logic [15:0] count,
  output logic done
);
  // Parameters
  localparam MAX_INT = 32767;
  localparam MIN_INT = -32768;
  parameter NUM_CHEM = 8;
  parameter MAX_P = 16;

  // State definitions
  parameter IDLE = 3'b000;
  parameter PREP_POWERS = 3'b001;
  parameter CALC_PREFIX = 3'b010;
  parameter CHECK_SUMS = 3'b011;
  parameter DONE = 3'b100;

  // Internal signals
  logic [2:0] state;
  logic signed [15:0] sum_reg;
  logic [3:0] i_idx; // up to 9
  logic [15:0] total_count;
  logic [15:0] final_count;
  logic [7:0] timer_cnt;
  logic done_reg;
  logic [15:0] count_out;
  logic [3:0] p_idx;
  logic overflow;
  logic [3:0] num_pows;
  logic signed [15:0] power [0:15];
  logic signed [15:0] dict_sum [0:15];
  logic [7:0] dict_cnt [0:15];
  logic dict_valid [0:15];

  // Main state machine
  always_ff @(posedge clk) begin
    if (!rst_n || !start) begin
      state <= IDLE;
      sum_reg <= 0;
      i_idx <= 0;
      total_count <= 0;
      final_count <= 0;
      timer_cnt <= 0;
      done_reg <= 0;
      count_out <= 0;
      p_idx <= 0;
      overflow <= 0;
      num_pows <= 0;
      for (int i=0; i<16; i++) begin
        power[i] <= 0;
        dict_sum[i] <= 0;
        dict_cnt[i] <= 0;
        dict_valid[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREP_POWERS;
          end
        end
        PREP_POWERS: begin
          // Compute powers of k
          if (p_idx == 0) begin
            power[0] <= 1;
            num_pows <= 1;
            p_idx <= 1;
          end else if (!overflow) begin
            logic signed [31:0] tmp;
            tmp = $signed(power[p_idx-1]) * $signed(k);
            if (tmp > MAX_INT || tmp < MIN_INT) begin
              overflow <= 1;
            end else begin
              power[p_idx] <= tmp[15:0];
              num_pows <= num_pows + 1;
              p_idx <= p_idx + 1;
            end
          end
          // Transition to prefix calculation when all powers are ready
          if (p_idx == MAX_P || overflow) begin
            state <= CALC_PREFIX;
            // Initialize for prefix processing
            sum_reg <= 0;
            i_idx <= 0;
            total_count <= 0;
            for (int i=0; i<16; i++) begin
              dict_valid[i] <= 0;
              dict_cnt[i] <= 0;
              dict_sum[i] <= 0;
            end
          end
        end
        CALC_PREFIX: begin
          // sum_reg already holds current prefix sum
          state <= CHECK_SUMS;
        end
        CHECK_SUMS: begin
          // Compute number of new valid segments for this prefix sum
          logic [15:0] add_sig;
          add_sig = 0;
          logic signed [15:0] target;
          for (int p=0; p<num_pows; p++) begin
            target = sum_reg - power[p];
            for (int i=0; i<16; i++) begin
              if (dict_valid[i] && dict_sum[i] == target) begin
                add_sig += dict_cnt[i];
              end
            end
          end
          total_count <= total_count + add_sig;

          // Update dictionary with current prefix sum
          int idx_f = -1;
          int idx_free = -1;
          for (int i=0; i<16; i++) begin
            if (dict_valid[i] && dict_sum[i] == sum_reg) idx_f = i;
            if (!dict_valid[i] && idx_free == -1) idx_free = i;
          end
          if (idx_f != -1) begin
            dict_cnt[idx_f] <= dict_cnt[idx_f] + 1;
          end else if (idx_free != -1) begin
            dict_sum[idx_free] <= sum_reg;
            dict_cnt[idx_free] <= 1;
            dict_valid[idx_free] <= 1;
          end

          // Prepare next prefix sum
          if (i_idx < NUM_CHEM) begin
            sum_reg <= sum_reg + $signed(a[i_idx]);
          end
          // Move to next index
          i_idx <= i_idx + 1;

          // Determine next state
          if (i_idx == NUM_CHEM) begin
            // Last prefix sum processed
            state <= DONE;
            final_count <= total_count + add_sig;
          end else begin
            state <= CALC_PREFIX;
          end
        end
        DONE: begin
          // Remain in DONE; timer will be handled below
        end
        default: state <= IDLE;
      endcase

      // Cycle counter for 200-cycle latency
      if (state != IDLE) begin
        timer_cnt <= timer_cnt + 1;
      end

      // Assert done and output result after 200 cycles
      if (timer_cnt == 199) begin
        done_reg <= 1;
        count_out <= final_count;
      end
    end
  end

  // Output assignments
  assign count = count_out;
  assign done = done_reg;

endmodule