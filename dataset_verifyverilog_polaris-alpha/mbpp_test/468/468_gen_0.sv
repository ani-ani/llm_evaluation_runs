module max_inc_subseq_product(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  arr [0:7],
  output logic [31:0] max_product,
  output logic        done
);

  // Internal registers
  logic [31:0] mpis     [0:7];
  logic [2:0]  cycle_cnt;
  logic        computing;

  // Max function for 32-bit values
  function automatic [31:0] max32(input [31:0] a, input [31:0] b);
    max32 = (a > b) ? a : b;
  endfunction

  // Sequential control and computation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      integer i_rst;
      for (i_rst = 0; i_rst < 8; i_rst = i_rst + 1) begin
        mpis[i_rst] <= 32'd0;
      end
      max_product <= 32'd0;
      done        <= 1'b0;
      cycle_cnt   <= 3'd0;
      computing   <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !computing) begin
        // Start of computation: cycle 0 - initialize mpis from arr
        integer i_init;
        for (i_init = 0; i_init < 8; i_init = i_init + 1) begin
          mpis[i_init] <= {24'd0, arr[i_init]};
        end
        max_product <= 32'd0;
        cycle_cnt   <= 3'd0;
        computing   <= 1'b1;
      end else if (computing) begin
        cycle_cnt <= cycle_cnt + 3'd1;

        // Cycle-based operations
        case (cycle_cnt)
          3'd0: begin
            // Process pair (0,1)
            if (arr[0] < arr[1]) begin
              logic [31:0] prod01;
              prod01 = mpis[0] * arr[1];
              mpis[1] <= max32(mpis[1], prod01);
            end
          end

          3'd1: begin
            // Process pair (1,2)
            if (arr[1] < arr[2]) begin
              logic [31:0] prod12;
              prod12 = mpis[1] * arr[2];
              mpis[2] <= max32(mpis[2], prod12);
            end
          end

          3'd2: begin
            // Process pair (2,3)
            if (arr[2] < arr[3]) begin
              logic [31:0] prod23;
              prod23 = mpis[2] * arr[3];
              mpis[3] <= max32(mpis[3], prod23);
            end
          end

          3'd3: begin
            // Process pair (3,4)
            if (arr[3] < arr[4]) begin
              logic [31:0] prod34;
              prod34 = mpis[3] * arr[4];
              mpis[4] <= max32(mpis[4], prod34);
            end
          end

          3'd4: begin
            // Process pair (4,5)
            if (arr[4] < arr[5]) begin
              logic [31:0] prod45;
              prod45 = mpis[4] * arr[5];
              mpis[5] <= max32(mpis[5], prod45);
            end
          end

          3'd5: begin
            // Process pair (5,6)
            if (arr[5] < arr[6]) begin
              logic [31:0] prod56;
              prod56 = mpis[5] * arr[6];
              mpis[6] <= max32(mpis[6], prod56);
            end
          end

          3'd6: begin
            // Process pair (6,7)
            if (arr[6] < arr[7]) begin
              logic [31:0] prod67;
              prod67 = mpis[6] * arr[7];
              mpis[7] <= max32(mpis[7], prod67);
            end
          end

          3'd7: begin
            // Final cycle (8th after start): compute maximum from mpis
            integer i_max;
            logic [31:0] max_val;
            max_val = mpis[0];
            for (i_max = 1; i_max < 8; i_max = i_max + 1) begin
              max_val = max32(max_val, mpis[i_max]);
            end
            max_product <= max_val;
            done        <= 1'b1;
            computing   <= 1'b0;
          end

          default: begin
            // Should not occur
          end
        endcase
      end
    end
  end

endmodule