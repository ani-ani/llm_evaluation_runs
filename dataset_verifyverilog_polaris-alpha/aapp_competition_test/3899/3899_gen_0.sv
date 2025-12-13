module task_threshold(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation (pulse)
  input [31:0] power [0:3], // Task power requirements (4 tasks)
  input [7:0] processors [0:3], // Processor counts (4 tasks)
  output reg [31:0] result, // Computed threshold ×1000
  output reg done // High when computation complete
);

  // Internal registers for start edge detection
  reg start_d;
  wire start_pulse;

  // Sorted powers and processors (descending power)
  reg [31:0] p [0:3];
  reg [7:0]  c [0:3];

  // Working registers
  reg [31:0] min_thr;      // minimal threshold found (x1000)
  reg        active;       // computation active flag
  reg [5:0]  cycle_cnt;    // to generate done 50 cycles after start

  // Compare-swap helper task for sorting network
  task automatic cswap_desc;
    inout [31:0] a_p;
    inout [7:0]  a_c;
    inout [31:0] b_p;
    inout [7:0]  b_c;
    reg   [31:0] tmp_p;
    reg   [7:0]  tmp_c;
    begin
      if (a_p < b_p) begin
        tmp_p = a_p; a_p = b_p; b_p = tmp_p;
        tmp_c = a_c; a_c = b_c; b_c = tmp_c;
      end
    end
  endtask

  // Start edge detection
  assign start_pulse = start & ~start_d;

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d   <= 1'b0;
      active    <= 1'b0;
      cycle_cnt <= 6'd0;
      done      <= 1'b0;
      result    <= 32'd0;
      min_thr   <= 32'hFFFFFFFF; // large default
    end else begin
      start_d <= start;

      // On start pulse: latch inputs, sort, compute min threshold, start 50-cycle delay
      if (start_pulse) begin
        // Latch inputs into p,c
        p[0] <= power[0]; c[0] <= processors[0];
        p[1] <= power[1]; c[1] <= processors[1];
        p[2] <= power[2]; c[2] <= processors[2];
        p[3] <= power[3]; c[3] <= processors[3];

        // Initialize control
        active    <= 1'b1;
        cycle_cnt <= 6'd0;
        done      <= 1'b0;
        min_thr   <= 32'hFFFFFFFF;
      end

      // Once inputs are latched on start_pulse, perform computation in next cycle
      if (active) begin
        cycle_cnt <= cycle_cnt + 6'd1;

        // At cycle_cnt == 1, perform sorting and threshold evaluation (single-cycle for simplicity)
        if (cycle_cnt == 6'd1) begin
          // Use local temporaries for combinational-like operations
          reg [31:0] sp0, sp1, sp2, sp3;
          reg [7:0]  sc0, sc1, sc2, sc3;
          reg [3:0]  mask;
          reg [31:0] sum_p;
          reg [15:0] sum_c;
          reg [63:0] num;
          reg [31:0] thr;

          // Snapshot latched values
          sp0 = p[0]; sc0 = c[0];
          sp1 = p[1]; sc1 = c[1];
          sp2 = p[2]; sc2 = c[2];
          sp3 = p[3]; sc3 = c[3];

          // 4-input sorting network (descending power)
          cswap_desc(sp0, sc0, sp1, sc1);
          cswap_desc(sp2, sc2, sp3, sc3);
          cswap_desc(sp0, sc0, sp2, sc2);
          cswap_desc(sp1, sc1, sp3, sc3);
          cswap_desc(sp1, sc1, sp2, sc2);

          // Evaluate all 16 pairing configurations.
          // Interpretation: bit i == 1 => task i starts a new computer (cannot be assigned as a second task).
          // For each configuration, we ensure for every non-starting task that its power is strictly less than
          // the power of at least one starting task with which it could pair. We choose greedy pairing:
          // each non-start task pairs with the most powerful eligible start task that has not yet taken a second task.
          // If any non-start task cannot find such a start task, config is invalid.

          min_thr = 32'hFFFFFFFF;

          for (mask = 4'b0001; mask <= 4'b1111; mask = mask + 1) begin
            // Require at least one starting task
            if (mask != 4'b0000) begin
              // Track if each start task already has a second task assigned
              reg used0, used1, used2, used3;
              reg valid;
              used0 = 1'b0;
              used1 = 1'b0;
              used2 = 1'b0;
              used3 = 1'b0;
              valid = 1'b1;

              sum_p = 32'd0;
              sum_c = 16'd0;

              // Add all starting tasks to sums
              if (mask[0]) begin sum_p = sum_p + sp0; sum_c = sum_c + sc0; end
              if (mask[1]) begin sum_p = sum_p + sp1; sum_c = sum_c + sc1; end
              if (mask[2]) begin sum_p = sum_p + sp2; sum_c = sum_c + sc2; end
              if (mask[3]) begin sum_p = sum_p + sp3; sum_c = sum_c + sc3; end

              // Greedy pairing for non-start tasks
              // Helper macro-style pairing attempt
              // Try to pair task with index t with a higher-power start task that has free slot
              // using manual code for each t for synthesis friendliness.

              // Task 0 as non-start (shouldn't happen if mask[0]==1 and sp sorted, but keep generic)
              if (!mask[0]) begin
                // find start j with spj > sp0
                if (mask[0] && !used0 && (sp0 < sp0)) begin end // unreachable
                else if (mask[1] && !used1 && (sp1 > sp0)) begin used1 = 1'b1; sum_p = sum_p + sp0; sum_c = sum_c + sc0; end
                else if (mask[2] && !used2 && (sp2 > sp0)) begin used2 = 1'b1; sum_p = sum_p + sp0; sum_c = sum_c + sc0; end
                else if (mask[3] && !used3 && (sp3 > sp0)) begin used3 = 1'b1; sum_p = sum_p + sp0; sum_c = sum_c + sc0; end
                else valid = 1'b0;
              end

              // Task 1 as non-start
              if (valid && !mask[1]) begin
                if (mask[0] && !used0 && (sp0 > sp1)) begin used0 = 1'b1; sum_p = sum_p + sp1; sum_c = sum_c + sc1; end
                else if (mask[2] && !used2 && (sp2 > sp1)) begin used2 = 1'b1; sum_p = sum_p + sp1; sum_c = sum_c + sc1; end
                else if (mask[3] && !used3 && (sp3 > sp1)) begin used3 = 1'b1; sum_p = sum_p + sp1; sum_c = sum_c + sc1; end
                else valid = 1'b0;
              end

              // Task 2 as non-start
              if (valid && !mask[2]) begin
                if (mask[0] && !used0 && (sp0 > sp2)) begin used0 = 1'b1; sum_p = sum_p + sp2; sum_c = sum_c + sc2; end
                else if (mask[1] && !used1 && (sp1 > sp2)) begin used1 = 1'b1; sum_p = sum_p + sp2; sum_c = sum_c + sc2; end
                else if (mask[3] && !used3 && (sp3 > sp2)) begin used3 = 1'b1; sum_p = sum_p + sp2; sum_c = sum_c + sc2; end
                else valid = 1'b0;
              end

              // Task 3 as non-start
              if (valid && !mask[3]) begin
                if (mask[0] && !used0 && (sp0 > sp3)) begin used0 = 1'b1; sum_p = sum_p + sp3; sum_c = sum_c + sc3; end
                else if (mask[1] && !used1 && (sp1 > sp3)) begin used1 = 1'b1; sum_p = sum_p + sp3; sum_c = sum_c + sc3; end
                else if (mask[2] && !used2 && (sp2 > sp3)) begin used2 = 1'b1; sum_p = sum_p + sp3; sum_c = sum_c + sc3; end
                else valid = 1'b0;
              end

              // If valid and sum_c non-zero, compute ceiling((sum_p / sum_c) * 1000)
              if (valid && (sum_c != 16'd0)) begin
                num = (sum_p * 64'd1000);
                thr = num[63:32] / sum_c; // placeholder, refine below using full 64-bit division
                // Perform exact 64-bit / 16-bit division for ceiling
                begin
                  reg [63:0] q;
                  reg [63:0] r;
                  q = num / sum_c;
                  r = num % sum_c;
                  if (r != 0) q = q + 1;
                  thr = q[31:0];
                end

                if (thr < min_thr)
                  min_thr = thr;
              end
            end
          end

          // After scanning all masks, update result with min_thr
          if (min_thr == 32'hFFFFFFFF)
            result <= 32'd0;
          else
            result <= min_thr;
        end

        // Assert done at 50 cycles after start
        if (cycle_cnt == 6'd50) begin
          done   <= 1'b1;
          active <= 1'b0;
        end
      end else begin
        // When not active, keep done as is (latched) until next start
        if (start_pulse) begin
          // handled above
        end
      end
    end
  end

endmodule