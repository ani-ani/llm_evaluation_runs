module election_solver (
  input clk, rst_n, start,
  input [2:0] n, k,
  input [4:0] m, a,
  input [4:0] vote_count [0:7],
  input [4:0] last_vote [0:7],
  output reg [1:0] result [0:7],
  output reg done
);

  function automatic [4:0] compute_cost;
    input [4:0] v_j, v_i, last_j, last_i, a;
    begin
      if (v_j > v_i) 
        compute_cost = 5'd0;
      else if (v_j == v_i) 
        if (last_j < last_i)
          compute_cost = 5'd0;
        else
          compute_cost = 5'd1;
      else begin
        reg [4:0] need1, need2;
        need1 = v_i - v_j + 5'd1;
        if (v_i - v_j == 5'd1 && last_i > a)
          need2 = 5'd1;
        else
          need2 = need1;
        compute_cost = (need1 < need2) ? need1 : need2;
      end
    end
  endfunction

  reg [1:0] next_result [0:7];
  integer i, j, idx, p, q, s;
  reg [4:0] costs [0:6];
  reg [4:0] temp;
  reg [4:0] total_cost;
  reg [4:0] R;
  reg [4:0] count;

  always @(*) begin
    R = m - a;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        idx = 0;
        for (j = 0; j < 8; j = j + 1) begin
          if (j < n && j != i) begin
            costs[idx] = compute_cost(vote_count[j], vote_count[i], last_vote[j], last_vote[i], a);
            idx = idx + 1;
          end
        end
        for (p = 0; p < idx - 1; p = p + 1) begin
          for (q = 0; q < idx - 1 - p; q = q + 1) begin
            if (costs[q] > costs[q + 1]) begin
              temp = costs[q];
              costs[q] = costs[q + 1];
              costs[q + 1] = temp;
            end
          end
        end
        total_cost = 5'd0;
        for (s = 0; s < k; s = s + 1) begin
          if (s < idx)
            total_cost = total_cost + costs[s];
        end
        if (total_cost > R)
          next_result[i] = 2'd1;
        else begin
          if (vote_count[i] + R == 5'd0)
            next_result[i] = 2'd3;
          else begin
            count = 5'd0;
            for (j = 0; j < 8; j = j + 1) begin
              if (j < n && j != i) begin
                if (vote_count[j] > vote_count[i] + R)
                  count = count + 5'd1;
                else if (vote_count[j] == vote_count[i] + R && last_vote[j] < m - 5'd1)
                  count = count + 5'd1;
              end
            end
            if (count < k)
              next_result[i] = 2'd2;
            else
              next_result[i] = 2'd3;
          end
        end
      end else begin
        next_result[i] = 2'd0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 8; i = i + 1) begin
        result[i] <= 2'd0;
      end
      done <= 1'b0;
    end else begin
      if (start) begin
        for (i = 0; i < 8; i = i + 1) begin
          result[i] <= next_result[i];
        end
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule