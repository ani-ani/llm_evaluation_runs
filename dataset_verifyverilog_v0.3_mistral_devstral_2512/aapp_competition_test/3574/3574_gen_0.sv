module magical_subarray(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] L,
    input [3:0] R,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Array storage
    reg [7:0] arr [0:7];
    
    // Computation variables
    reg [3:0] i_reg, j_reg;
    reg [3:0] max_len;
    reg [3:0] current_len;
    reg [7:0] min_val, max_val;
    reg [7:0] current_val;
    reg is_magical;
    reg [3:0] k_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize array
            arr[0] <= 8'd0;
            arr[1] <= 8'd0;
            arr[2] <= 8'd0;
            arr[3] <= 8'd0;
            arr[4] <= 8'd0;
            arr[5] <= 8'd0;
            arr[6] <= 8'd0;
            arr[7] <= 8'd0;
            
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            max_len <= 4'd0;
            current_len <= 4'd0;
            min_val <= 8'd0;
            max_val <= 8'd0;
            current_val <= 8'd0;
            is_magical <= 1'b0;
            k_reg <= 4'd0;
        end else begin
            // Update array from inputs
            arr[0] <= arr_0;
            arr[1] <= arr_1;
            arr[2] <= arr_2;
            arr[3] <= arr_3;
            arr[4] <= arr_4;
            arr[5] <= arr_5;
            arr[6] <= arr_6;
            arr[7] <= arr_7;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i_reg <= L - 4'd1;
                        j_reg <= L - 4'd1;
                        max_len <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current subarray [i_reg, j_reg] is magical
                    if (i_reg <= j_reg) begin
                        min_val <= arr[i_reg];
                        max_val <= arr[i_reg];
                        is_magical <= 1'b1;
                        k_reg <= i_reg + 4'd1;
                        
                        // Find min and max in subarray
                        while (k_reg <= j_reg) begin
                            current_val <= arr[k_reg];
                            if (current_val < min_val) begin
                                min_val <= current_val;
                            end
                            if (current_val > max_val) begin
                                max_val <= current_val;
                            end
                            k_reg <= k_reg + 4'd1;
                        end
                        
                        // Check if all elements are between min and max
                        k_reg <= i_reg;
                        while (k_reg <= j_reg && is_magical) begin
                            current_val <= arr[k_reg];
                            if (current_val < min_val || current_val > max_val) begin
                                is_magical <= 1'b0;
                            end
                            k_reg <= k_reg + 4'd1;
                        end
                        
                        // Update max length if magical
                        if (is_magical) begin
                            current_len <= j_reg - i_reg + 4'd1;
                            if (current_len > max_len) begin
                                max_len <= current_len;
                            end
                        end
                        
                        // Move to next subarray
                        if (j_reg < R - 4'd1) begin
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            i_reg <= i_reg + 4'd1;
                            j_reg <= i_reg;
                        end
                    end
                    
                    // Check if done with all subarrays
                    if (i_reg > R - 4'd1 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= max_len;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule