module election_predictor(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] m_remaining,
  input [2:0] candidate_id,
  input [7:0] current_votes,
  input [7:0] last_vote_time,
  input load_data,
  output reg [1:0] result,
  output reg done
);

typedef enum logic [2:0] {IDLE, SORT, CALC, OUTPUT} state_t;
reg [2:0] current_state, next_state;
reg [7:0] votes_reg [0:7];
reg [7:0] times_reg [0:7];
reg [7:0] sorted_votes [0:7];
reg [7:0] sorted_times [0:7];
reg [1:0] results [0:7];

reg [2:0] n_reg, k_reg;
reg [7:0] m_remaining_reg;

reg [2:0] sort_pass, sort_index;
reg [2:0] output_idx;

wire sort_done;
wire [2:0] n_minus_1 = n_reg - 1;

assign sort_done = (sort_pass >= n_minus_1) || (n_reg == 0);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    for (int i=0; i<8; i++) begin
      votes_reg[i] <= 8'b0;
      times_reg[i] <= 8'b0;
      sorted_votes[i] <= 8'b0;
      sorted_times[i] <= 8'b0;
    end
    done <= 0;
    result <= 0;
    sort_pass <= 0;
    sort_index <= 0;
    output_idx <= 0;
    n_reg <= 0;
    k_reg <= 0;
    m_remaining_reg <= 0;
  end else begin
    current_state <= next_state;

    case (current_state)
      IDLE: begin
        done <= 0;
        if (load_data) begin
          votes_reg[candidate_id] <= current_votes;
          times_reg[candidate_id] <= last_vote_time;
        end
        if (start) begin
          n_reg <= n;
          k_reg <= k;
          m_remaining_reg <= m_remaining;
          for (int i=0; i<8; i++) begin
            sorted_votes[i] <= votes_reg[i];
            sorted_times[i] <= times_reg[i];
          end
          sort_pass <= 0;
          sort_index <= 0;
        end
      end

      SORT: begin
        if (!sort_done) begin
          if (sort_index < (n_reg - sort_pass - 1)) begin
            if ((sorted_votes[sort_index] < sorted_votes[sort_index+1]) || 
                ((sorted_votes[sort_index] == sorted_votes[sort_index+1]) && 
                 (sorted_times[sort_index] > sorted_times[sort_index+1]))) begin
              sorted_votes[sort_index] <= sorted_votes[sort_index+1];
              sorted_votes[sort_index+1] <= sorted_votes[sort_index];
              sorted_times[sort_index] <= sorted_times[sort_index+1];
              sorted_times[sort_index+1] <= sorted_times[sort_index];
            end
            sort_index <= sort_index + 1;
          end else begin
            sort_index <= 0;
            sort_pass <= sort_pass + 1;
          end
        end
      end

      CALC: begin
        if (n_reg == 0) begin
          for (int i=0; i<8; i++) results[i] = 2'b0;
        end else if (k_reg >= n_reg) begin
          for (int i=0; i<8; i++) results[i] = (i < n_reg) ? 2'b01 : 2'b0;
        end else begin
          for (int i=0; i<8; i++) begin
            if (i < n_reg) begin
              if (i < k_reg) begin
                if (sorted_votes[i] > (sorted_votes[k_reg] + m_remaining_reg))
                  results[i] = 2'b01;
                else
                  results[i] = 2'b10;
              end else begin
                if ((sorted_votes[i] + m_remaining_reg) > sorted_votes[k_reg-1])
                  results[i] = 2'b10;
                else
                  results[i] = 2'b11;
              end
            end else results[i] = 2'b0;
          end
        end
        output_idx <= 0;
      end

      OUTPUT: begin
        done <= 1;
        if (output_idx < n_reg) begin
          result <= results[output_idx];
          output_idx <= output_idx + 1;
        end else done <= 0;
      end
    endcase
  end
end

always_comb begin
  next_state = current_state;
  case (current_state)
    IDLE: next_state = (start) ? SORT : IDLE;
    SORT: next_state = (sort_done) ? CALC : SORT;
    CALC: next_state = OUTPUT;
    OUTPUT: next_state = (done && (output_idx >= n_reg)) ? IDLE : OUTPUT;
    default: next_state = IDLE;
  endcase
end

endmodule