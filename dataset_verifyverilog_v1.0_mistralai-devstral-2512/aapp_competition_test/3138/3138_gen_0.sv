module SubarrayCounter(
    input clk,
    input rst_n,
    input start,
    input [9:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] result_reg;
    reg [3:0] i_reg, j_reg;
    reg [15:0] sum_reg;
    reg [31:0] product_reg;
    reg [9:0] arr_reg [0:15];
    reg [3:0] len_reg;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd2000;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 8'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            sum_reg <= 16'd0;
            product_reg <= 32'd0;
            cycle_count <= 16'd0;
            
            // Initialize array registers
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                arr_reg[k] <= 10'd0;
            end
            len_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        // Capture inputs
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            arr_reg[k] <= arr[k];
                        end
                        len_reg <= len;
                        
                        // Initialize counters
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        result_reg <= 8'd0;
                        
                        state <= CALCULATING;
                    end
                end
                
                CALCULATING: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        // Calculate sum and product for current subarray
                        if (j_reg == i_reg) begin
                            // Initialize for new subarray starting at i_reg
                            sum_reg <= arr_reg[i_reg];
                            product_reg <= arr_reg[i_reg];
                            j_reg <= j_reg + 4'd1;
                        end else if (j_reg < len_reg) begin
                            // Accumulate sum and product
                            sum_reg <= sum_reg + arr_reg[j_reg];
                            
                            // Product with overflow protection
                            if (product_reg > 32'd0 && product_reg <= 32'd1000000) begin
                                product_reg <= product_reg * arr_reg[j_reg];
                            end else if (product_reg == 32'd0) begin
                                product_reg <= 32'd0;
                            end else begin
                                product_reg <= 32'd1000001; // Cap to prevent overflow
                            end
                            
                            // Check if sum equals product
                            if (sum_reg == product_reg[15:0]) begin
                                result_reg <= result_reg + 8'd1;
                            end
                            
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            // Move to next i
                            i_reg <= i_reg + 4'd1;
                            
                            // Check if we've processed all subarrays
                            if (i_reg >= len_reg - 4'd1) begin
                                state <= DONE_STATE;
                            end else begin
                                j_reg <= i_reg + 4'd1;
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule