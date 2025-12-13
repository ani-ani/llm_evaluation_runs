module sum_squares(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic       [3:0]  length,
  input  logic signed [15:0] lst_0,
  input  logic signed [15:0] lst_1,
  input  logic signed [15:0] lst_2,
  input  logic signed [15:0] lst_3,
  input  logic signed [15:0] lst_4,
  input  logic signed [15:0] lst_5,
  input  logic signed [15:0] lst_6,
  input  logic signed [15:0] lst_7,
  output logic signed [31:0] sum,
  output logic              done
);

  // Internal registers
  logic [3:0] idx;
  logic       busy;
  logic signed [15:0] curr_val;
  logic signed [31:0] term;
  logic signed [31:0] sum_r;
  logic       done_r;

  // Select current element based on idx
  always_comb begin
    unique case (idx)
      4'd0: curr_val = lst_0;
      4'd1: curr_val = lst_1;
      4'd2: curr_val = lst_2;
      4'd3: curr_val = lst_3;
      4'd4: curr_val = lst_4;
      4'd5: curr_val = lst_5;
      4'd6: curr_val = lst_6;
      4'd7: curr_val = lst_7;
      default: curr_val = '0;
    endcase
  end

  // Compute term based on index rule
  always_comb begin
    if ((idx % 3) == 0) begin
      // square
      term = curr_val * curr_val;
    end else if ((idx % 4) == 0) begin
      // cube
      term = curr_val * curr_val * curr_val;
    end else begin
      // original value
      term = {{16{curr_val[15]}}, curr_val};
    end
  end

  // Sequential control and accumulation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx    <= 4'd0;
      sum_r  <= 32'sd0;
      done_r <= 1'b0;
      busy   <= 1'b0;
    end else begin
      if (start) begin
        // Start new operation
        idx    <= 4'd0;
        sum_r  <= 32'sd0;
        done_r <= 1'b0;
        busy   <= (length != 4'd0);
        // If length is zero, computation is trivially done next cycle
      end else if (busy) begin
        if (idx < length) begin
          sum_r <= sum_r + term;
          idx   <= idx + 4'd1;
          if (idx + 4'd1 >= length) begin
            done_r <= 1'b1;
            busy   <= 1'b0;
          end
        end else begin
          done_r <= 1'b1;
          busy   <= 1'b0;
        end
      end
      // Hold done_r and sum_r after completion until next start/reset
    end
  end

  // Output registers (sum valid 1 cycle after done asserts)
  logic signed [31:0] sum_q;
  logic               done_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_q  <= 32'sd0;
      done_q <= 1'b0;
    end else begin
      done_q <= done_r;
      if (done_r)
        sum_q <= sum_r;
    end
  end

  assign sum  = sum_q;
  assign done = done_q;

endmodule