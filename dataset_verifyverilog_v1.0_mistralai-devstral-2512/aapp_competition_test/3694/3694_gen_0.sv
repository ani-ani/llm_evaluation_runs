module stones_game(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [31:0] arr [0:15],
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] CHECK_DUPLICATES = 3'd2;
    localparam [2:0] COMPUTE_TOTAL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for sorted array
    reg [31:0] sorted_arr [0:15];
    reg [3:0] i, j, k;
    reg [31:0] temp;
    reg [31:0] total;
    reg [31:0] duplicate_value;
    reg duplicate_count;
    reg has_duplicate;
    reg has_duplicate_minus_one;
    reg has_zero_duplicate;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize sorted array
            for (i = 0; i < 16; i = i + 1) begin
                sorted_arr[i] <= 32'd0;
            end
            
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp <= 32'd0;
            total <= 32'd0;
            duplicate_value <= 32'd0;
            duplicate_count <= 1'b0;
            has_duplicate <= 1'b0;
            has_duplicate_minus_one <= 1'b0;
            has_zero_duplicate <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SORT;
                        
                        // Copy input array to sorted array
                        for (i = 0; i < 16; i = i + 1) begin
                            sorted_arr[i] <= arr[i];
                        end
                        
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation
                    if (i < len - 1) begin
                        if (j < len - i - 1) begin
                            if (sorted_arr[j] > sorted_arr[j + 1]) begin
                                temp <= sorted_arr[j];
                                sorted_arr[j] <= sorted_arr[j + 1];
                                sorted_arr[j + 1] <= temp;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= CHECK_DUPLICATES;
                        k <= 4'd1;  // Start checking from index 1
                        duplicate_count <= 1'b0;
                        has_duplicate <= 1'b0;
                        has_duplicate_minus_one <= 1'b0;
                        has_zero_duplicate <= 1'b0;
                    end
                end

                CHECK_DUPLICATES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (k < len) begin
                        // Check for duplicates
                        if (sorted_arr[k] == sorted_arr[k - 1]) begin
                            if (!has_duplicate) begin
                                has_duplicate <= 1'b1;
                                duplicate_value <= sorted_arr[k];
                                duplicate_count <= duplicate_count + 1;
                                
                                // Check if duplicate is 0
                                if (duplicate_value == 32'd0) begin
                                    has_zero_duplicate <= 1'b1;
                                end
                            end else begin
                                duplicate_count <= duplicate_count + 1;
                            end
                        end
                        k <= k + 1;
                    end else begin
                        // Check if (duplicate_value - 1) exists
                        if (has_duplicate && duplicate_value != 32'd0) begin
                            for (i = 0; i < len; i = i + 1) begin
                                if (sorted_arr[i] == duplicate_value - 32'd1) begin
                                    has_duplicate_minus_one <= 1'b1;
                                end
                            end
                        end
                        
                        // Determine winner based on conditions
                        if (duplicate_count > 1 || 
                            (duplicate_count == 1 && (has_zero_duplicate || has_duplicate_minus_one))) begin
                            result <= 2'd0;  // CSL wins
                        end else begin
                            next_state <= COMPUTE_TOTAL;
                            total <= 32'd0;
                            i <= 4'd0;
                        end
                    end
                end

                COMPUTE_TOTAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i < len) begin
                        total <= total + sorted_arr[i];
                        i <= i + 1;
                    end else begin
                        // Compute total = sum(a) - n*(n-1)/2
                        total <= total - (len * (len - 1)) / 2;
                        
                        // Check parity
                        if (total[0] == 1'b0) begin
                            result <= 2'd0;  // CSL wins
                        end else begin
                            result <= 2'd1;  // Tokitsukaze wins
                        end
                        
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule