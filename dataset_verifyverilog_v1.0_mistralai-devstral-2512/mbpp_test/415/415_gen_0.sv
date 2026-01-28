module max_product_pair (
    input clk,
    input rst_n,
    input signed [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg signed [7:0] pair_a,
    output reg signed [7:0] pair_b,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STAGE1 = 2'd1;
    localparam [1:0] STAGE2 = 2'd2;
    
    reg [1:0] state;
    
    // Stage 1: Find max and min
    reg signed [7:0] max_val;
    reg signed [7:0] min_val;
    
    // Stage 2: Compute products
    reg signed [15:0] max_product;
    reg signed [15:0] min_product;
    
    // Pipeline registers
    reg signed [7:0] max_val_reg;
    reg signed [7:0] min_val_reg;
    
    // Find max and min in parallel
    always @(*) begin
        // Initialize with first element
        max_val = arr_0;
        min_val = arr_0;
        
        // Compare with all other elements
        if (arr_1 > max_val) max_val = arr_1;
        if (arr_1 < min_val) min_val = arr_1;
        
        if (arr_2 > max_val) max_val = arr_2;
        if (arr_2 < min_val) min_val = arr_2;
        
        if (arr_3 > max_val) max_val = arr_3;
        if (arr_3 < min_val) min_val = arr_3;
        
        if (arr_4 > max_val) max_val = arr_4;
        if (arr_4 < min_val) min_val = arr_4;
        
        if (arr_5 > max_val) max_val = arr_5;
        if (arr_5 < min_val) min_val = arr_5;
        
        if (arr_6 > max_val) max_val = arr_6;
        if (arr_6 < min_val) min_val = arr_6;
        
        if (arr_7 > max_val) max_val = arr_7;
        if (arr_7 < min_val) min_val = arr_7;
    end
    
    // Compute products
    always @(*) begin
        max_product = $signed(max_val) * $signed(max_val);
        min_product = $signed(min_val) * $signed(min_val);
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_val_reg <= 8'd0;
            min_val_reg <= 8'd0;
            pair_a <= 8'd0;
            pair_b <= 8'd0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    state <= STAGE1;
                end
                
                STAGE1: begin
                    // Store max and min values
                    max_val_reg <= max_val;
                    min_val_reg <= min_val;
                    state <= STAGE2;
                end
                
                STAGE2: begin
                    // Compare products and output result
                    if (max_product >= min_product) begin
                        pair_a <= max_val_reg;
                        pair_b <= max_val_reg;
                    end else begin
                        pair_a <= min_val_reg;
                        pair_b <= min_val_reg;
                    end
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule