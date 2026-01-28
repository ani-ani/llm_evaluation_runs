module large_product #(
    parameter LIST_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter N_WIDTH = 4,
    parameter RESULT_WIDTH = 16
  ) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] nums1_0, nums1_1, nums1_2, nums1_3,
    input wire [DATA_WIDTH-1:0] nums1_4, nums1_5, nums1_6, nums1_7,
    input wire [DATA_WIDTH-1:0] nums2_0, nums2_1, nums2_2, nums2_3,
    input wire [DATA_WIDTH-1:0] nums2_4, nums2_5, nums2_6, nums2_7,
    input wire [N_WIDTH-1:0] len1,
    input wire [N_WIDTH-1:0] len2,
    input wire [N_WIDTH-1:0] N,
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

  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] GENERATE_PRODUCTS = 3'd1;
  localparam [2:0] SORT_PRODUCTS = 3'd2;
  localparam [2:0] OUTPUT_RESULTS = 3'd3;
  
  reg [2:0] current_state, next_state;
  reg [5:0] prod_idx;
  reg [3:0] i1, i2;
  reg [3:0] sort_pass;
  reg [3:0] output_idx;
  reg [N_WIDTH-1:0] valid_N;
  reg [5:0] num_to_sort;
  
  reg [RESULT_WIDTH-1:0] product_array [0:63];
  reg [RESULT_WIDTH-1:0] sorted_array [0:63];
  
  integer j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      i1 <= 4'd0;
      i2 <= 4'd0;
      prod_idx <= 6'd0;
      sort_pass <= 4'd0;
      output_idx <= 4'd0;
      valid_N <= 4'd0;
      num_to_sort <= 6'd0;
      
      products_0 <= 16'd0;
      products_1 <= 16'd0;
      products_2 <= 16'd0;
      products_3 <= 16'd0;
      products_4 <= 16'd0;
      products_5 <= 16'd0;
      products_6 <= 16'd0;
      products_7 <= 16'd0;
      
      for (j = 0; j < 64; j = j + 1) begin
        product_array[j] <= 16'd0;
        sorted_array[j] <= 16'd0;
      end
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            i1 <= 4'd0;
            i2 <= 4'd0;
            prod_idx <= 6'd0;
            sort_pass <= 4'd0;
            output_idx <= 4'd0;
            valid_N <= (N > 64) ? 64 : N;
          end
        end
        
        GENERATE_PRODUCTS: begin
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
          
          sorted_array[prod_idx] <= product_array[prod_idx];
          
          prod_idx <= prod_idx + 6'd1;
          i2 <= i2 + 4'd1;
          if (i2 >= len2) begin
            i2 <= 4'd0;
            i1 <= i1 + 4'd1;
          end
        end
        
        SORT_PRODUCTS: begin
          if (sort_pass < num_to_sort - 1) begin
            if (sorted_array[sort_pass] < sorted_array[sort_pass + 1]) begin
              sorted_array[sort_pass] <= sorted_array[sort_pass + 1];
              sorted_array[sort_pass + 1] <= sorted_array[sort_pass];
            end
            sort_pass <= sort_pass + 4'd1;
          end else if (sort_pass == num_to_sort - 1) begin
            sort_pass <= 4'd0;
            num_to_sort <= num_to_sort - 6'd1;
          end
        end
        
        OUTPUT_RESULTS: begin
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
            output_idx <= output_idx + 4'd1;
          end else begin
            done <= 1'b1;
          end
        end
      endcase
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start && len1 > 0 && len2 > 0 && N > 0)
          next_state = GENERATE_PRODUCTS;
      end
      
      GENERATE_PRODUCTS: begin
        if (i1 >= len1)
          next_state = SORT_PRODUCTS;
      end
      
      SORT_PRODUCTS: begin
        if (num_to_sort <= 1)
          next_state = OUTPUT_RESULTS;
      end
      
      OUTPUT_RESULTS: begin
        if (output_idx >= valid_N && done)
          next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end

  always @(*) begin
    if (current_state == IDLE && start)
      num_to_sort <= len1 * len2;
  end

endmodule