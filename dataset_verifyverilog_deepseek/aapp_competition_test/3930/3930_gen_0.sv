module love_potion_counter(
  input clk,
  input rst_n,
  input start,
  input signed [7:0] a [0:7],
  input signed [7:0] k,
  output reg [15:0] count,
  output reg done
);

  typedef enum logic [2:0] {IDLE, PREP_POWERS, CALC_PREFIX, CHECK_SUMS, DONE} state_t;
  state_t state, next_state;
  
  reg [15:0] cycle_count;
  reg signed [15:0] powers [0:15];
  reg [3:0] num_powers;
  reg [3:0] p_counter;
  reg signed [15:0] prefix_sums [0:8];
  reg signed [15:0] dict_sum [0:15];
  reg [15:0] dict_count [0:15];
  reg [15:0] dict_valid;
  reg [3:0] i;
  reg [3:0] j;
  reg [15:0] accum_count;
  reg signed [15:0] current_sum;
  reg signed [15:0] target;
  reg signed [23:0] temp_product;
  reg power_overflow;
  wire dict_match;
  wire [3:0] dict_match_idx;
  wire dict_has_free;
  wire [3:0] dict_free_idx;

  always_comb begin
    dict_match = 1'b0;
    dict_match_idx = 4'd0;
    for (int m=0; m<16; m=m+1) begin
      if (dict_valid[m] & (dict_sum[m] == current_sum)) begin
        dict_match = 1'b1;
        dict_match_idx = m;
      end
    end
  end

  always_comb begin
    dict_has_free = 1'b0;
    dict_free_idx = 4'd0;
    for (int n=0; n<16; n=n+1) begin
      if (!dict_valid[n]) begin
        dict_has_free = 1'b1;
        dict_free_idx = n;
        break;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= (cycle_count >= 16'd199);
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PREP_POWERS;
      PREP_POWERS: if ((p_counter == 4'd15) || power_overflow) next_state = CALC_PREFIX;
      CALC_PREFIX: if (prefix_sums[8] !== 'bx) next_state = CHECK_SUMS;
      CHECK_SUMS: if (i >= 4'd8 && j >= num_powers) next_state = DONE;
      DONE: if (!start) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 16'd0;
      p_counter <= 4'd0;
      num_powers <= 4'd0;
      powers <= '{default: '0};
      power_overflow <= 1'b0;
      prefix_sums <= '{default: '0};
      dict_sum <= '{default: '0};
      dict_count <= '{default: '0};
      dict_valid <= 16'd0;
      i <= 4'd1;
      j <= 4'd0;
      accum_count <= 16'd0;
      count <= 16'd0;
      current_sum <= 16'd0;
      target <= 16'd0;
    end else begin
      cycle_count <= (state != IDLE) ? cycle_count + 16'd1 : 16'd0;
      case (state)
        IDLE: begin
          p_counter <= 4'd0;
          num_powers <= 4'd0;
          power_overflow <= 1'b0;
          dict_valid <= 16'd1;
          dict_count[0] <= 16'd1;
          dict_sum[0] <= 16'd0;
        end
        
        PREP_POWERS: begin
          if (p_counter == 4'd0) begin
            powers[0] <= 16'sd1;
            num_powers <= 4'd1;
            p_counter <= p_counter + 4'd1;
          end else if (!power_overflow && (p_counter < 4'd16)) begin
            temp_product = $signed(powers[p_counter-1]) * $signed({{8{k[7]}},k});
            if (temp_product > 24'sd32767 || temp_product < -24'sd32768) begin
              power_overflow <= 1'b1;
            end else begin
              powers[p_counter] <= temp_product[15:0];
              num_powers <= p_counter + 4'd1;
              p_counter <= p_counter + 4'd1;
            end
          end
        end
        
        CALC_PREFIX: begin
          prefix_sums[0] <= 16'd0;
          prefix_sums[1] <= $signed(a[0]);
          prefix_sums[2] <= $signed(prefix_sums[1]) + $signed(a[1]);
          prefix_sums[3] <= $signed(prefix_sums[2]) + $signed(a[2]);
          prefix_sums[4] <= $signed(prefix_sums[3]) + $signed(a[3]);
          prefix_sums[5] <= $signed(prefix_sums[4]) + $signed(a[4]);
          prefix_sums[6] <= $signed(prefix_sums[5]) + $signed(a[5]);
          prefix_sums[7] <= $signed(prefix_sums[6]) + $signed(a[6]);
          prefix_sums[8] <= $signed(prefix_sums[7]) + $signed(a[7]);
        end
        
        CHECK_SUMS: begin
          current_sum <= prefix_sums[i];
          if (j < num_powers) begin
            target <= current_sum - $signed(powers[j]);
            for (int k=0; k<16; k=k+1) begin
              if (dict_valid[k] && (dict_sum[k] == target)) begin
                accum_count <= accum_count + dict_count[k];
              end
            end
            j <= j + 4'd1;
          end else begin
            count <= count + accum_count;
            accum_count <= 16'd0;
            j <= 4'd0;
            if (dict_match) begin
              dict_count[dict_match_idx] <= dict_count[dict_match_idx] + 16'd1;
            end else if (dict_has_free) begin
              dict_sum[dict_free_idx] <= current_sum;
              dict_count[dict_free_idx] <= 16'd1;
              dict_valid[dict_free_idx] <= 1'b1;
            end
            i <= i + 4'd1;
          end
        end
        
        DONE: begin
          if (!start) begin
            count <= 16'd0;
            dict_valid <= 16'd0;
            dict_valid[0] <= 1'b1;
            dict_count[0] <= 16'd1;
            dict_sum[0] <= 16'd0;
            i <= 4'd1;
            j <= 4'd0;
          end
        end
      endcase
    end
  end
endmodule