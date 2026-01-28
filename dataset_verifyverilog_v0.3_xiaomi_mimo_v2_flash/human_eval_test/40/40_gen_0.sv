module triples_sum_to_zero (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SETUP = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state, next_state;
    reg [2:0] i, j, k;           // Indices for triple loop
    reg found_triplet;            // Flag if triplet found
    reg [7:0] arr_i, arr_j, arr_k; // Registered array elements
    wire signed [7:0] sum;       // 8-bit signed sum
    
    // Combinational sum calculation
    assign sum = arr_i + arr_j + arr_k;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SETUP: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Check if triplet found or all combinations checked
                if (found_triplet || (i >= len - 3'd2)) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd1;
            k <= 3'd2;
            found_triplet <= 1'b0;
            arr_i <= 8'sd0;
            arr_j <= 8'sd0;
            arr_k <= 8'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        found_triplet <= 1'b0;
                        result <= 1'b0;
                    end
                end
                
                SETUP: begin
                    i <= 3'd0;
                    j <= 3'd1;
                    k <= 3'd2;
                    // Register initial array elements
                    arr_i <= arr[0];
                    arr_j <= arr[1];
                    arr_k <= arr[2];
                end
                
                COMPUTE: begin
                    if (!found_triplet) begin
                        // Check if current triplet sums to zero
                        if (sum == 8'sd0) begin
                            found_triplet <= 1'b1;
                            result <= 1'b1;
                        end else begin
                            // Increment k first
                            if (k < len - 3'd1) begin
                                k <= k + 3'd1;
                                arr_k <= arr[k + 3'd1];
                            end else begin
                                // Reset k and increment j
                                k <= j + 3'd1;
                                arr_k <= arr[j + 3'd1];
                                j <= j + 3'd1;
                                arr_j <= arr[j + 3'd1];
                                // If j reaches end, reset j and increment i
                                if (j >= len - 3'd1) begin
                                    j <= i + 3'd1;
                                    arr_j <= arr[i + 3'd1];
                                    i <= i + 3'd1;
                                    arr_i <= arr[i + 3'd1];
                                end
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Keep result value until next operation
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule