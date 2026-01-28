module large_product #(
    parameter LIST_SIZE = 8,    // Maximum size of input lists
    parameter DATA_WIDTH = 8,   // Width of each number
    parameter N_WIDTH = 4,      // Width of N parameter (max 16)
    parameter RESULT_WIDTH = 16 // Width of product result
  ) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input lists - using individual ports for clarity
    // Each list has up to 8 elements, valid elements indicated by len
    input wire [DATA_WIDTH-1:0] nums1_0, nums1_1, nums1_2, nums1_3,
    input wire [DATA_WIDTH-1:0] nums1_4, nums1_5, nums1_6, nums1_7,
    input wire [DATA_WIDTH-1:0] nums2_0, nums2_1, nums2_2, nums2_3,
    input wire [DATA_WIDTH-1:0] nums2_4, nums2_5, nums2_6, nums2_7,
    
    input wire [N_WIDTH-1:0] len1,  // Number of valid elements in nums1
    input wire [N_WIDTH-1:0] len2,  // Number of valid elements in nums2  
    input wire [N_WIDTH-1:0] N,     // Number of largest products to return
    
    // Output ports - top N products in descending order
    output reg [RESULT_WIDTH-1:0] products_0,
    output reg [RESULT_WIDTH-1:0] products_1,
    output reg [RESULT_WIDTH-1:0] products_2,
    output reg [RESULT_WIDTH-1:0] products_3,
    output reg [RESULT_WIDTH-1:0] products_4,
    output reg [RESULT_WIDTH-1:0] products_5,
    output reg [RESULT_WIDTH-1:0] products_6,
    output reg [RESULT_WIDTH-1:0] products_7,
    
    output reg done
  );
  
  // Maximum products: 8x8 = 64 products
  localparam MAX_PRODUCTS = 64;
  localparam LOG_MAX_PRODUCTS = 6; // ceil(log2(64))
  
  // State machine states
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] GENERATE_PRODUCTS = 3'd1;
  localparam [2:0] SORT_PRODUCTS = 3'd2;
  localparam [2:0] OUTPUT_RESULTS = 3'd3;
  localparam [2:0] FINISH = 3'd4;
  
  reg [2:0] current_state, next_state;
  
  // Storage for all generated products
  reg [RESULT_WIDTH-1:0] product_array [0:MAX_PRODUCTS-1];
  
  // Working array for sorting (also holds final sorted results)
  reg [RESULT_WIDTH-1:0] sorted_array [0:MAX_PRODUCTS-1];
  
  // Counters
  reg [3:0] i1, i2;  // Iterators for product generation
  reg [5:0] prod_idx; // Index for product storage
  reg [5:0] sort_pass; // Sorting pass counter
  reg [3:0] output_idx; // Output index counter
  reg [N_WIDTH-1:0] valid_N; // Clamped N value
  reg [5:0] num_to_sort;     // Number of elements to sort
  
  // Control signals
  reg [5:0] num_to_generate; // Number of products to generate
  
  integer j;
  
  // State transition and sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      products_0 <= 0; products_1 <= 0; products_2 <= 0; products_3 <= 0;
      products_4 <= 0; products_5 <= 0; products_6 <= 0; products_7 <= 0;
      done <= 0;
      i1 <= 0; i2 <= 0; prod_idx <= 0; sort_pass <= 0; output_idx <= 0;
      valid_N <= 0;
      num_to_sort <= 0;
      num_to_generate <= 0;
      // Clear product arrays
      for (j = 0; j < MAX_PRODUCTS; j = j + 1) begin
        product_array[j] <= 0;
        sorted_array[j] <= 0;
      end
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            i1 <= 0; i2 <= 0; prod_idx <= 0; sort_pass <= 0; output_idx <= 0;
            // Clamp N to valid range and max products
            valid_N <= (N > MAX_PRODUCTS) ? MAX_PRODUCTS : N;
          end
        end
        
        GENERATE_PRODUCTS: begin
          // Store product for current i1, i2
          case (i1)
            0: case (i2)
              0: product_array[prod_idx] <= nums1_0 * nums2_0;
              1: product_array[prod_idx] <= nums1_0 * nums2_1;
              2: product_array[prod_idx] <= nums1_0 * nums2_2;
              3: product_array[prod_idx] <= nums1_0 * nums2_3;
              4: product_array[prod_idx] <= nums1_0 * nums2_4;
              5: product_array[prod_idx] <= nums1_0 * nums2_5;
              6: product_array[prod_idx] <= nums1_0 * nums2_6;
              7: product_array[prod_idx] <= nums1_0 * nums2_7;
            endcase
            1: case (i2)
              0: product_array[prod_idx] <= nums1_1 * nums2_0;
              1: product_array[prod_idx] <= nums1_1 * nums2_1;
              2: product_array[prod_idx] <= nums1_1 * nums2_2;
              3: product_array[prod_idx] <= nums1_1 * nums2_3;
              4: product_array[prod_idx] <= nums1_1 * nums2_4;
              5: product_array[prod_idx] <= nums1_1 * nums2_5;
              6: product_array[prod_idx] <= nums1_1 * nums2_6;
              7: product_array[prod_idx] <= nums1_1 * nums2_7;
            endcase
            2: case (i2)
              0: product_array[prod_idx] <= nums1_2 * nums2_0;
              1: product_array[prod_idx] <= nums1_2 * nums2_1;
              2: product_array[prod_idx] <= nums1_2 * nums2_2;
              3: product_array[prod_idx] <= nums1_2 * nums2_3;
              4: product_array[prod_idx] <= nums1_2 * nums2_4;
              5: product_array[prod_idx] <= nums1_2 * nums2_5;
              6: product_array[prod_idx] <= nums1_2 * nums2_6;
              7: product_array[prod_idx] <= nums1_2 * nums2_7;
            endcase
            3: case (i2)
              0: product_array[prod_idx] <= nums1_3 * nums2_0;
              1: product_array[prod_idx] <= nums1_3 * nums2_1;
              2: product_array[prod_idx] <= nums1_3 * nums2_2;
              3: product_array[prod_idx] <= nums1_3 * nums2_3;
              4: product_array[prod_idx] <= nums1_3 * nums2_4;
              5: product_array[prod_idx] <= nums1_3 * nums2_5;
              6: product_array[prod_idx] <= nums1_3 * nums2_6;
              7: product_array[prod_idx] <= nums1_3 * nums2_7;
            endcase
            4: case (i2)
              0: product_array[prod_idx] <= nums1_4 * nums2_0;
              1: product_array[prod_idx] <= nums1_4 * nums2_1;
              2: product_array[prod_idx] <= nums1_4 * nums2_2;
              3: product_array[prod_idx] <= nums1_4 * nums2_3;
              4: product_array[prod_idx] <= nums1_4 * nums2_4;
              5: product_array[prod_idx] <= nums1_4 * nums2_5;
              6: product_array[prod_idx] <= nums1_4 * nums2_6;
              7: product_array[prod_idx] <= nums1_4 * nums2_7;
            endcase
            5: case (i2)
              0: product_array[prod_idx] <= nums1_5 * nums2_0;
              1: product_array[prod_idx] <= nums1_5 * nums2_1;
              2: product_array[prod_idx] <= nums1_5 * nums2_2;
              3: product_array[prod_idx] <= nums1_5 * nums2_3;
              4: product_array[prod_idx] <= nums1_5 * nums2_4;
              5: product_array[prod_idx] <= nums1_5 * nums2_5;
              6: product_array[prod_idx] <= nums1_5 * nums2_6;
              7: product_array[prod_idx] <= nums1_5 * nums2_7;
            endcase
            6: case (i2)
              0: product_array[prod_idx] <= nums1_6 * nums2_0;
              1: product_array[prod_idx] <= nums1_6 * nums2_1;
              2: product_array[prod_idx] <= nums1_6 * nums2_2;
              3: product_array[prod_idx] <= nums1_6 * nums2_3;
              4: product_array[prod_idx] <= nums1_6 * nums2_4;
              5: product_array[prod_idx] <= nums1_6 * nums2_5;
              6: product_array[prod_idx] <= nums1_6 * nums2_6;
              7: product_array[prod_idx] <= nums1_6 * nums2_7;
            endcase
            7: case (i2)
              0: product_array[prod_idx] <= nums1_7 * nums2_0;
              1: product_array[prod_idx] <= nums1_7 * nums2_1;
              2: product_array[prod_idx] <= nums1_7 * nums2_2;
              3: product_array[prod_idx] <= nums1_7 * nums2_3;
              4: product_array[prod_idx] <= nums1_7 * nums2_4;
              5: product_array[prod_idx] <= nums1_7 * nums2_5;
              6: product_array[prod_idx] <= nums1_7 * nums2_6;
              7: product_array[prod_idx] <= nums1_7 * nums2_7;
            endcase
          endcase
          
          // Copy to sorted array initially
          sorted_array[prod_idx] <= product_array[prod_idx];
          
          // Increment counters
          prod_idx <= prod_idx + 1;
          i2 <= i2 + 1;
          if (i2 == len2 - 1) begin
            i2 <= 0;
            i1 <= i1 + 1;
          end
        end
        
        SORT_PRODUCTS: begin
          // Bubble sort pass - compare adjacent elements and swap if needed
          // We only sort the first num_to_sort elements
          if (sort_pass < num_to_sort - 1) begin
            // Perform comparison and potential swap
            if (sorted_array[sort_pass] < sorted_array[sort_pass + 1]) begin
              // Swap
              sorted_array[sort_pass] <= sorted_array[sort_pass + 1];
              sorted_array[sort_pass + 1] <= sorted_array[sort_pass];
            end
            sort_pass <= sort_pass + 1;
          end else if (sort_pass == num_to_sort - 1) begin
            // One full pass completed, check if we need another pass
            sort_pass <= 0;
            // Decrement counter for next pass - we need num_to_sort passes for full sort
            num_to_sort <= num_to_sort - 1;
            // If num_to_sort becomes 1 or less, sorting complete
          end
        end
        
        OUTPUT_RESULTS: begin
          // Output top N products in descending order
          if (output_idx < valid_N) begin
            case (output_idx)
              0: products_0 <= sorted_array[0];
              1: products_1 <= sorted_array[1];
              2: products_2 <= sorted_array[2];
              3: products_3 <= sorted_array[3];
              4: products_4 <= sorted_array[4];
              5: products_5 <= sorted_array[5];
              6: products_6 <= sorted_array[6];
              7: products_7 <= sorted_array[7];
            endcase
            output_idx <= output_idx + 1;
          end else begin
            done <= 1;
          end
        end
        
        FINISH: begin
          done <= 1;
        end
        
        default: begin
          current_state <= IDLE;
        end
      endcase
      
      // Additional products to generate
      if (current_state == IDLE && start) begin
        num_to_generate <= len1 * len2;
        num_to_sort <= len1 * len2;
      end
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start && len1 > 0 && len2 > 0 && N > 0)
          next_state = GENERATE_PRODUCTS;
      end
      
      GENERATE_PRODUCTS: begin
        // Done when all products generated
        if (i1 >= len1 || (i1 == len1 - 1 && i2 >= len2)) begin
          next_state = SORT_PRODUCTS;
        end
      end
      
      SORT_PRODUCTS: begin
        // Done when sorting complete (num_to_sort becomes 1)
        if (num_to_sort <= 1) begin
          next_state = OUTPUT_RESULTS;
        end
      end
      
      OUTPUT_RESULTS: begin
        if (output_idx >= valid_N) begin
          next_state = FINISH;
        end
      end
      
      FINISH: begin
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
endmodule