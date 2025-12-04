typedef struct packed {
  logic [3:0] sum;
  logic [3:0] num1;
  logic [3:0] num2;
} pair_t;

module k_min_pairs (
  input clk, rst_n,
  input [2:0] array1_size, array2_size,
  input [3:0] nums1 [0:7],
  input [3:0] nums2 [0:7],
  input [5:0] k,
  output reg [3:0] pairs [0:15][0:1],
  output reg valid
);

  // Input tracking
  reg [2:0] prev_array1_size, prev_array2_size;
  reg [3:0] prev_nums1 [0:7], prev_nums2 [0:7];
  reg [5:0] prev_k;
  wire inputs_changed = (array1_size != prev_array1_size) ||
                        (array2_size != prev_array2_size) ||
                        (k != prev_k) ||
                        (nums1[0] != prev_nums1[0]) || (nums1[1] != prev_nums1[1]) ||
                        (nums1[2] != prev_nums1[2]) || (nums1[3] != prev_nums1[3]) ||
                        (nums1[4] != prev_nums1[4]) || (nums1[5] != prev_nums1[5]) ||
                        (nums1[6] != prev_nums1[6]) || (nums1[7] != prev_nums1[7]) ||
                        (nums2[0] != prev_nums2[0]) || (nums2[1] != prev_nums2[1]) ||
                        (nums2[2] != prev_nums2[2]) || (nums2[3] != prev_nums2[3]) ||
                        (nums2[4] != prev_nums2[4]) || (nums2[5] != prev_nums2[5]) ||
                        (nums2[6] != prev_nums2[6]) || (nums2[7] != prev_nums2[7]);

  // Work registers
  reg [2:0] work_array1_size, work_array2_size;
  reg [5:0] work_k;
  reg [3:0] work_nums1 [0:7], work_nums2 [0:7];
  
  // Data pipeline
  pair_t [0:63] pipe [0:9];  // 10-stage pipeline
  
  // Valid shift register
  reg [9:0] valid_sr;

  // Sort stage function
  function automatic pair_t [0:63] sort_stage(pair_t [0:63] arr, input int parity);
    pair_t [0:63] sorted;
    sorted = arr;
    for (int i = 0; i < 63; i++) begin
      if ((i % 2) == parity) begin  // Even/odd index check
        if (sorted[i].sum > sorted[i+1].sum) begin  // Swap condition
          pair_t temp = sorted[i];
          sorted[i] = sorted[i+1];
          sorted[i+1] = temp;
        end
      end
    end
    return sorted;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset logic
      prev_array1_size <= 0;
      prev_array2_size <= 0;
      prev_k <= 0;
      foreach (prev_nums1[i]) prev_nums1[i] <= 0;
      foreach (prev_nums2[i]) prev_nums2[i] <= 0;
      work_array1_size <= 0;
      work_array2_size <= 0;
      work_k <= 0;
      foreach (work_nums1[i]) work_nums1[i] <= 0;
      foreach (work_nums2[i]) work_nums2[i] <= 0;
      foreach (pipe[i]) pipe[i] <= '{default:0};
      valid_sr <= 0;
      valid <= 0;
      foreach (pairs[i]) pairs[i] <= '{0,0};
    end else begin
      // Update input trackers
      prev_array1_size <= array1_size;
      prev_array2_size <= array2_size;
      prev_k <= k;
      prev_nums1 <= nums1;
      prev_nums2 <= nums2;

      // Update worksets on change
      if (inputs_changed) begin
        work_array1_size <= array1_size;
        work_array2_size <= array2_size;
        work_k <= k;
        work_nums1 <= nums1;
        work_nums2 <= nums2;
        
        // Generate initial pairs
        automatic int actual_pairs = work_array1_size * work_array2_size;
        foreach (pipe[0][i]) begin
          if (i < actual_pairs) begin
            automatic int x = i / 8;
            automatic int y = i % 8;
            pipe[0][i].num1 <= work_nums1[x];
            pipe[0][i].num2 <= work_nums2[y];
            pipe[0][i].sum <= work_nums1[x] + work_nums2[y];
          end else begin
            pipe[0][i].num1 <= 0;
            pipe[0][i].num2 <= 0;
            pipe[0][i].sum <= 4'b1111; // Push invalid to end
          end
        end
        
        valid_sr <= 10'b0000000001; // Start valid shift
      end else begin
        valid_sr <= valid_sr << 1; // Shift valid register
        
        // Shift pipeline
        pipe[1] <= sort_stage(pipe[0], 0);  // Stage 0: Even parity
        pipe[2] <= sort_stage(pipe[1], 1);  // Stage 1: Odd parity
        pipe[3] <= sort_stage(pipe[2], 0);  // Stage 2: Even
        pipe[4] <= sort_stage(pipe[3], 1);  // Stage 3: Odd
        pipe[5] <= sort_stage(pipe[4], 0);  // Stage 4: Even
        pipe[6] <= sort_stage(pipe[5], 1);  // Stage 5: Odd
        pipe[7] <= sort_stage(pipe[6], 0);  // Stage 6: Even
        pipe[8] <= sort_stage(pipe[7], 1);  // Stage 7: Odd
        pipe[9] <= sort_stage(pipe[8], 0);  // Stage 8: Even (Total 9 sorting stages)
      end

      // Drive outputs from final stage
      automatic int actual_pairs = work_array1_size * work_array2_size;
      automatic int output_count = (work_k < actual_pairs) ? work_k : actual_pairs;
      foreach (pairs[i]) begin
        if (i < output_count) begin
          pairs[i][0] <= pipe[9][i].num1;
          pairs[i][1] <= pipe[9][i].num2;
        end else begin
          pairs[i][0] <= 0;
          pairs[i][1] <= 0;
        end
      end
      
      // Valid from shift register
      valid <= valid_sr[9];
    end
  end
endmodule