module large_product #(
    parameter LIST_SIZE = 8,    // Maximum size of input lists
    parameter DATA_WIDTH = 8,   // Width of each number
    parameter N_WIDTH = 4,      // Width of N parameter (max 16)
    parameter RESULT_WIDTH = 16 // Width of product result
  ) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input lists
    input wire [DATA_WIDTH-1:0] nums1_0, nums1_1, nums1_2, nums1_3,
    input wire [DATA_WIDTH-1:0] nums1_4, nums1_5, nums1_6, nums1_7,
    input wire [DATA_WIDTH-1:0] nums2_0, nums2_1, nums2_2, nums2_3,
    input wire [DATA_WIDTH-1:0] nums2_4, nums2_5, nums2_6, nums2_7,
    
    input wire [N_WIDTH-1:0] len1,  // Valid elements in nums1
    input wire [N_WIDTH-1:0] len2,  // Valid elements in nums2
    input wire [N_WIDTH-1:0] N,     // Products to return
    
    // Output ports
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
  
  // State declarations
  localparam [2:0] IDLE              = 3'd0;
  localparam [2:0] GENERATE_PRODUCTS = 3'd1;
  localparam [2:0] SORT_PRODUCTS     = 3'd2;
  localparam [2:0] OUTPUT_RESULTS    = 3'd3;
  
  // Constants
  localparam [5:0] MAX_PRODUCTS = 6'd64;  // 8*8=64
  localparam [N_WIDTH-1:0] MAX_CLAMP = (LIST_SIZE >= 8) ? 8'd8 : LIST_SIZE;  // Max output ports
  
  // Internal registers
  reg [2:0] current_state, next_state;
  reg [RESULT_WIDTH-1:0] product_array [0:63];  // 64 products
  reg [RESULT_WIDTH-1:0] sorted_array [0:63];   // Sorting buffer
  
  // Control registers
  reg [3:0] i1, i2;                // Generation indices
  reg [5:0] prod_count;            // Product counter
  reg [5:0] sort_idx;              // Sorting index
  reg [5:0] sort_target;           // Target for sorting
  reg [2:0] output_idx;            // Output index
  reg [N_WIDTH-1:0] clamped_N;     // Validated N value
  reg [5:0] products_generated;    // Actual product count
  
  integer i;  // Loop variable
  
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      prod_count <= 6'd0;
      i1 <= 4'd0;
      i2 <= 4'd0;
      sort_idx <= 6'd0;
      sort_target <= 6'd0;
      output_idx <= 3'd0;
      products_generated <= 6'd0;
      clamped_N <= 4'd0;
      
      // Clear output registers
      products_0 <= {RESULT_WIDTH{1'b0}};
      products_1 <= {RESULT_WIDTH{1'b0}};
      products_2 <= {RESULT_WIDTH{1'b0}};
      products_3 <= {RESULT_WIDTH{1'b0}};
      products_4 <= {RESULT_WIDTH{1'b0}};
      products_5 <= {RESULT_WIDTH{1'b0}};
      products_6 <= {RESULT_WIDTH{1'b0}};
      products_7 <= {RESULT_WIDTH{1'b0}};
      
      // Initialize arrays
      for (i = 0; i < MAX_PRODUCTS; i = i + 1) begin
        product_array[i] <= {RESULT_WIDTH{1'b0}};
        sorted_array[i] <= {RESULT_WIDTH{1'b0}};
      end
    end 
    else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          output_idx <= 3'd0;
          if (start) begin
            clamped_N <= (N > MAX_CLAMP) ? MAX_CLAMP : N;
            products_generated <= len1 * len2;
            prod_count <= 6'd0;
            i1 <= 4'd0;
            i2 <= 4'd0;
          end
        end
        
        GENERATE_PRODUCTS: begin
          // Generate products via case statements
          case (i1)
            4'd0: case (i2)
              4'd0: product_array[prod_count] <= nums1_0 * nums2_0;
              4'd1: product_array[prod_count] <= nums1_0 * nums2_1;
              4'd2: product_array[prod_count] <= nums1_0 * nums2_2;
              4'd3: product_array[prod_count] <= nums1_0 * nums2_3;
              4'd4: product_array[prod_count] <= nums1_0 * nums2_4;
              4'd5: product_array[prod_count] <= nums1_0 * nums2_5;
              4'd6: product_array[prod_count] <= nums1_0 * nums2_6;
              4'd7: product_array[prod_count] <= nums1_0 * nums2_7;
            endcase
            4'd1: case (i2)
              4'd0: product_array[prod_count] <= nums1_1 * nums2_0;
              4'd1: product_array[prod_count] <= nums1_1 * nums2_1;
              // ... (similar for i1=1 to 7)
            endcase
            // ... (cases for i1=2 to 7)
          endcase
          
          // Copy to sorted array
          sorted_array[prod_count] <= product_array[prod_count];
          
          // Update counters
          if (i2 == len2 - 1) begin
            i2 <= 4'd0;
            i1 <= i1 + 1;
          end
          else begin
            i2 <= i2 + 1;
          end
          
          prod_count <= prod_count + 1;
        end
        
        SORT_PRODUCTS: begin
          // Bubble sort implementation
          if (sort_idx < sort_target) begin
            if (sorted_array[sort_idx] < sorted_array[sort_idx + 1]) begin
              // Swap
              sorted_array[sort_idx] <= sorted_array[sort_idx + 1];
              sorted_array[sort_idx + 1] <= sorted_array[sort_idx];
            end
            sort_idx <= sort_idx + 1;
          end
          else begin
            sort_idx <= 6'd0;
            sort_target <= sort_target - 1;
          end
        end
        
        OUTPUT_RESULTS: begin
          if (output_idx < clamped_N) begin
            case (output_idx)
              3'd0: products_0 <= sorted_array[output_idx];
              3'd1: products_1 <= sorted_array[output_idx];
              3'd2: products_2 <= sorted_array[output_idx];
              3'd3: products_3 <= sorted_array[output_idx];
              3'd4: products_4 <= sorted_array[output_idx];
              3'd5: products_5 <= sorted_array[output_idx];
              3'd6: products_6 <= sorted_array[output_idx];
              3'd7: products_7 <= sorted_array[output_idx];
            endcase
            output_idx <= output_idx + 1;
          end
          else begin
            done <= 1'b1;
          end
        end
      endcase
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start && (len1 > 0) && (len2 > 0) && (N > 0)) begin
          next_state = GENERATE_PRODUCTS;
        end
      end
      
      GENERATE_PRODUCTS: begin
        if (prod_count >= len1 * len2) begin
          next_state = SORT_PRODUCTS;
        end
      end
      
      SORT_PRODUCTS: begin
        if (sort_target == 1) begin  // Sort complete
          next_state = OUTPUT_RESULTS;
        end
      end
      
      OUTPUT_RESULTS: begin
        if (done) begin
          next_state = IDLE;
        end
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  // Sort initialization
  always @(posedge clk) begin
    if (current_state == GENERATE_PRODUCTS && next_state == SORT_PRODUCTS) begin
      sort_idx <= 6'd0;
      sort_target <= products_generated - 1;
    end
  end
  
endmodule