module min_k_finder(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] K,
  input  [3:0][7:0] names,
  input  [3:0][7:0] scores,
  output reg [3:0][7:0] min_names,
  output reg [3:0][7:0] min_scores,
  output reg   done
);

  // Internal registers
  reg [3:0][7:0] name_reg;
  reg [3:0][7:0] score_reg;

  reg [4:0]  cycle_cnt;      // to count up to 20
  reg        active;         // indicates computation in progress
  reg        start_d;
  wire       start_pulse;

  // Edge detect for start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  // Main sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      name_reg    <= '{default:8'd0};
      score_reg   <= '{default:8'd0};
      min_names   <= '{default:8'd0};
      min_scores  <= '{default:8'd0};
      done        <= 1'b0;
      active      <= 1'b0;
      cycle_cnt   <= 5'd0;
    end else begin
      if (start_pulse) begin
        // Load inputs and start operation
        name_reg   <= names;
        score_reg  <= scores;
        min_names  <= '{default:8'd0};
        min_scores <= '{default:8'd0};
        done       <= 1'b0;
        active     <= 1'b1;
        cycle_cnt  <= 5'd0;
      end else if (active) begin
        // Perform bubble sort passes over 6 stages within 20 cycles
        // We map compare-swap stages across early cycles; unused cycles just wait.

        // stage 0: compare (0,1)
        if (cycle_cnt == 5'd0) begin
          if (score_reg[0] > score_reg[1]) begin
            {score_reg[0], score_reg[1]} <= {score_reg[1], score_reg[0]};
            {name_reg[0],  name_reg[1]}  <= {name_reg[1],  name_reg[0]};
          end
        end
        // stage 1: compare (1,2)
        else if (cycle_cnt == 5'd1) begin
          if (score_reg[1] > score_reg[2]) begin
            {score_reg[1], score_reg[2]} <= {score_reg[2], score_reg[1]};
            {name_reg[1],  name_reg[2]}  <= {name_reg[2],  name_reg[1]};
          end
        end
        // stage 2: compare (2,3)
        else if (cycle_cnt == 5'd2) begin
          if (score_reg[2] > score_reg[3]) begin
            {score_reg[2], score_reg[3]} <= {score_reg[3], score_reg[2]};
            {name_reg[2],  name_reg[3]}  <= {name_reg[3],  name_reg[2]};
          end
        end
        // stage 3: compare (0,1)
        else if (cycle_cnt == 5'd3) begin
          if (score_reg[0] > score_reg[1]) begin
            {score_reg[0], score_reg[1]} <= {score_reg[1], score_reg[0]};
            {name_reg[0],  name_reg[1]}  <= {name_reg[1],  name_reg[0]};
          end
        end
        // stage 4: compare (1,2)
        else if (cycle_cnt == 5'd4) begin
          if (score_reg[1] > score_reg[2]) begin
            {score_reg[1], score_reg[2]} <= {score_reg[2], score_reg[1]};
            {name_reg[1],  name_reg[2]}  <= {name_reg[2],  name_reg[1]};
          end
        end
        // stage 5: compare (0,1)
        else if (cycle_cnt == 5'd5) begin
          if (score_reg[0] > score_reg[1]) begin
            {score_reg[0], score_reg[1]} <= {score_reg[1], score_reg[0]};
            {name_reg[0],  name_reg[1]}  <= {name_reg[1],  name_reg[0]};
          end
        end
        // cycles 6..18: idle (no operation, just waiting to meet 20-cycle latency)

        // At cycle 19 (20th cycle starting from 0) finalize outputs
        if (cycle_cnt == 5'd19) begin
          // Select first K elements; unset positions are zero
          // K assumed 1-3; clamp defensively to 0-4
          if (K > 8'd0) begin
            min_names[0]  <= name_reg[0];
            min_scores[0] <= score_reg[0];
          end else begin
            min_names[0]  <= 8'd0;
            min_scores[0] <= 8'd0;
          end

          if (K > 8'd1) begin
            min_names[1]  <= name_reg[1];
            min_scores[1] <= score_reg[1];
          end else begin
            min_names[1]  <= 8'd0;
            min_scores[1] <= 8'd0;
          end

          if (K > 8'd2) begin
            min_names[2]  <= name_reg[2];
            min_scores[2] <= score_reg[2];
          end else begin
            min_names[2]  <= 8'd0;
            min_scores[2] <= 8'd0;
          end

          // 4th output always zero (K max is 3)
          min_names[3]  <= 8'd0;
          min_scores[3] <= 8'd0;

          done   <= 1'b1;
          active <= 1'b0; // remain idle until next start
        end

        // Increment cycle counter while active
        if (active) begin
          if (cycle_cnt != 5'd19)
            cycle_cnt <= cycle_cnt + 5'd1;
        end
      end else begin
        // idle; hold outputs and done stable until next start
        done <= done; // explicit hold (no change)
      end
    end
  end

endmodule