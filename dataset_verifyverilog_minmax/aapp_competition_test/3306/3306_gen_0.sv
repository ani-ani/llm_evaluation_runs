module minimal_phone_calls(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,        // Number of detectors (1-8)
  input [15:0] M,       // Total houses (2-65535)
  input [15:0] P0,
  input [31:0] C0,
  input [15:0] P1,
  input [31:0] C1,
  input [15:0] P2,
  input [31:0] C2,
  input [15:0] P3,
  input [31:0] C3,
  input [15:0] P4,
  input [31:0] C4,
  input [15:0] P5,
  input [31:0] C5,
  input [15:0] P6,
  input [31:0] C6,
  input [15:0] P7,
  input [31:0] C7,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam NUM_DET = 8;
  localparam SORT_CYCLES = 28;   // 7+6+...+1 for 8 elements

  // Internal state and storage
  reg [3:0] state, next_state;
  reg [5:0] sort_counter;       // 0..27
  reg [3:0] n_det;              // Registered copy of N
  reg [15:0] houses;            // Registered copy of M

  // Combined P, C pairs for sorting
  reg [15:0] sort_pos [0:NUM_DET-1];
  reg [31:0] sort_cnt [0:NUM_DET-1];

  // Computation storage for first N detectors (after sorting)
  reg [15:0] pos_n [0:NUM_DET-1];
  reg [31:0] cnt_n [0:NUM_DET-1];

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 4'd0;
      result <= 32'd0;
      done <= 1'b0;
      n_det <= 4'd0;
      houses <= 16'd0;
      sort_counter <= 6'd0;
      for (int i = 0; i < NUM_DET; i++) begin
        sort_pos[i] <= 16'd0;
        sort_cnt[i] <= 32'd0;
        pos_n[i] <= 16'd0;
        cnt_n[i] <= 32'd0;
      end
    end else begin
      state <= next_state;
      done <= 1'b0;

      case (state)
        4'd0: begin // IDLE
          sort_counter <= 6'd0;
          if (start) begin
            n_det <= (N >= 4'd1 && N <= 4'd8) ? N : 4'd1;
            houses <= M;
            // Load inputs into sort arrays; pad invalid detectors with max position (to bubble to the end)
            sort_pos[0] <= P0;
            sort_cnt[0] <= C0;
            sort_pos[1] <= (n_det >= 4'd2 || start) ? P1 : 16'hFFFF; // latch P1 only if N>=2; else set invalid
            sort_cnt[1] <= (n_det >= 4'd2 || start) ? C1 : 32'd0;
            // We will fully reinitialize in LOAD state (next) to ensure correctness
          end
        end

        4'd1: begin // LOAD
          // Initialize based on N (on first cycle after start)
          n_det <= (N >= 4'd1 && N <= 4'd8) ? N : 4'd1;
          houses <= M;

          sort_pos[0] <= P0;
          sort_cnt[0] <= C0;
          sort_pos[1] <= (N >= 4'd2) ? P1 : 16'hFFFF;
          sort_cnt[1] <= (N >= 4'd2) ? C1 : 32'd0;
          sort_pos[2] <= (N >= 4'd3) ? P2 : 16'hFFFF;
          sort_cnt[2] <= (N >= 4'd3) ? C2 : 32'd0;
          sort_pos[3] <= (N >= 4'd4) ? P3 : 16'hFFFF;
          sort_cnt[3] <= (N >= 4'd4) ? C3 : 32'd0;
          sort_pos[4] <= (N >= 4'd5) ? P4 : 16'hFFFF;
          sort_cnt[4] <= (N >= 4'd5) ? C4 : 32'd0;
          sort_pos[5] <= (N >= 4'd6) ? P5 : 16'hFFFF;
          sort_cnt[5] <= (N >= 4'd6) ? C5 : 32'd0;
          sort_pos[6] <= (N >= 4'd7) ? P6 : 16'hFFFF;
          sort_cnt[6] <= (N >= 4'd7) ? C6 : 32'd0;
          sort_pos[7] <= (N >= 4'd8) ? P7 : 16'hFFFF;
          sort_cnt[7] <= (N >= 4'd8) ? C7 : 32'd0;

          sort_counter <= 6'd0;
        end

        4'd2: begin // SORT (bubble sort network for 28 cycles)
          sort_counter <= sort_counter + 1;
          // Perform the comparison for this cycle
          // Determine pair index k based on sort_counter
          // k = 0 -> (0,1), 1 -> (1,2), ..., 6 -> (6,7)
          // then 7 -> (0,1), 8 -> (1,2), ..., 13 -> (6,7)
          // ... total 28 cycles
          case (sort_counter[4:0]) // 0..27
            5'd0, 5'd7, 5'd14, 5'd21: begin
              if (sort_pos[0] > sort_pos[1]) begin
                {sort_pos[0], sort_cnt[0]} <= {sort_pos[1], sort_cnt[1]};
                {sort_pos[1], sort_cnt[1]} <= {sort_pos[0], sort_cnt[0]};
              end
            end
            5'd1, 5'd8, 5'd15, 5'd22: begin
              if (sort_pos[1] > sort_pos[2]) begin
                {sort_pos[1], sort_cnt[1]} <= {sort_pos[2], sort_cnt[2]};
                {sort_pos[2], sort_cnt[2]} <= {sort_pos[1], sort_cnt[1]};
              end
            end
            5'd2, 5'd9, 5'd16, 5'd23: begin
              if (sort_pos[2] > sort_pos[3]) begin
                {sort_pos[2], sort_cnt[2]} <= {sort_pos[3], sort_cnt[3]};
                {sort_pos[3], sort_cnt[3]} <= {sort_pos[2], sort_cnt[2]};
              end
            end
            5'd3, 5'd10, 5'd17, 5'd24: begin
              if (sort_pos[3] > sort_pos[4]) begin
                {sort_pos[3], sort_cnt[3]} <= {sort_pos[4], sort_cnt[4]};
                {sort_pos[4], sort_cnt[4]} <= {sort_pos[3], sort_cnt[3]};
              end
            end
            5'd4, 5'd11, 5'd18, 5'd25: begin
              if (sort_pos[4] > sort_pos[5]) begin
                {sort_pos[4], sort_cnt[4]} <= {sort_pos[5], sort_cnt[5]};
                {sort_pos[5], sort_cnt[5]} <= {sort_pos[4], sort_cnt[4]};
              end
            end
            5'd5, 5'd12, 5'd19, 5'd26: begin
              if (sort_pos[5] > sort_pos[6]) begin
                {sort_pos[5], sort_cnt[5]} <= {sort_pos[6], sort_cnt[6]};
                {sort_pos[6], sort_cnt[6]} <= {sort_pos[5], sort_cnt[5]};
              end
            end
            5'd6, 5'd13, 5'd20, 5'd27: begin
              if (sort_pos[6] > sort_pos[7]) begin
                {sort_pos[6], sort_cnt[6]} <= {sort_pos[7], sort_cnt[7]};
                {sort_pos[7], sort_cnt[7]} <= {sort_pos[6], sort_cnt[6]};
              end
            end
            default: ;
          endcase
        end

        4'd3: begin // PACK - pack only first N sorted entries
          for (int i = 0; i < NUM_DET; i++) begin
            if (i < n_det) begin
              pos_n[i] <= sort_pos[i];
              cnt_n[i] <= sort_cnt[i];
            end else begin
              pos_n[i] <= 16'd0;
              cnt_n[i] <= 32'd0;
            end
          end
        end

        4'd4: begin // COMPUTE - compute minimal calls
          // result = max( C0, max over i: (C_{i+1} - C_i) )
          // Handles wrap-around: (C0 - C_{N-1})
          result <= compute_min_calls(n_det, houses, cnt_n);
        end

        4'd5: begin // DONE
          done <= 1'b1;
        end

        default: begin
          // Stay idle on unexpected states
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    case (state)
      4'd0: next_state = start ? 4'd1 : 4'd0;
      4'd1: next_state = 4'd2;
      4'd2: next_state = (sort_counter == (SORT_CYCLES - 1)) ? 4'd3 : 4'd2;
      4'd3: next_state = 4'd4;
      4'd4: next_state = 4'd5;
      4'd5: next_state = 4'd0;
      default: next_state = 4'd0;
    endcase
  end

  // Function to compute minimal calls
  function [31:0] compute_min_calls;
    input [3:0] n;         // 1..8
    input [15:0] houses;   // total houses
    input [31:0] cn [0:NUM_DET-1]; // counts
    integer i;
    reg [31:0] max_val;
    reg [31:0] diff;
  begin
    max_val = cn[0];
    for (i = 0; i < NUM_DET - 1; i = i + 1) begin
      if (i < n - 1) begin
        diff = cn[i+1] - cn[i]; // unsigned subtraction, wraps as needed
        if (diff > max_val) max_val = diff;
      end
    end
    if (n > 1) begin
      diff = cn[0] - cn[n-1]; // wrap-around
      if (diff > max_val) max_val = diff;
    end
    compute_min_calls = max_val;
  end
  endfunction

endmodule