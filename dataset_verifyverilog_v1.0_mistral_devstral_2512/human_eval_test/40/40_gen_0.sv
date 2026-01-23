module triples_sum_to_zero(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SETUP   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    reg [1:0] state;
    reg [2:0] i, j, k;
    reg [7:0] sum;
    reg [7:0] arr_i, arr_j, arr_k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    i <= 3'd0;
                    j <= 3'd1;
                    k <= 3'd2;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Read array values
                    arr_i <= arr[i];
                    arr_j <= arr[j];
                    arr_k <= arr[k];
                    
                    // Calculate sum
                    sum <= arr_i + arr_j + arr_k;
                    
                    // Check if sum is zero
                    if (sum == 8'd0) begin
                        result <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Increment k
                        k <= k + 3'd1;
                        
                        // Check if k reached len
                        if (k >= len) begin
                            k <= j + 3'd2;
                            j <= j + 3'd1;
                            
                            // Check if j reached len-1
                            if (j >= len - 1) begin
                                j <= i + 3'd2;
                                i <= i + 3'd1;
                                
                                // Check if i reached len-2
                                if (i >= len - 2) begin
                                    result <= 1'b0;
                                    state <= DONE;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule