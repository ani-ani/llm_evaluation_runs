module MayorLawnDemolition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] s_arr [0:15],
    input wire [7:0] g_arr [0:15],
    output reg [15:0] result,
    output reg [7:0] s_prime_arr [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] FORWARD  = 3'd1;
    localparam [2:0] BACKWARD = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] L [0:15], R [0:15];
    reg [15:0] total_demolition;
    reg impossible;
    reg [7:0] current_L, current_R;
    reg [7:0] prev_L, prev_R;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            result <= 16'd0;
            impossible <= 1'b0;
            total_demolition <= 16'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                s_prime_arr[i] <= 8'd0;
                L[i] <= 8'd0;
                R[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= FORWARD;
                        index <= 4'd0;
                        impossible <= 1'b0;
                        
                        // Initialize L and R arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            L[i] <= s_arr[i];
                            R[i] <= s_arr[i] + g_arr[i];
                        end
                    end
                end

                FORWARD: begin
                    if (index < n) begin
                        // Process current element
                        if (index == 4'd0) begin
                            // First element, no previous constraints
                            current_L = L[index];
                            current_R = R[index];
                        end else begin
                            // Apply constraints from previous element
                            current_L = (L[index] > prev_L - 8'd1) ? L[index] : prev_L - 8'd1;
                            current_R = (R[index] < prev_R + 8'd1) ? R[index] : prev_R + 8'd1;
                        end
                        
                        // Check if impossible
                        if (current_L > current_R) begin
                            impossible <= 1'b1;
                        end
                        
                        // Store updated L and R
                        L[index] <= current_L;
                        R[index] <= current_R;
                        
                        // Update for next iteration
                        prev_L <= current_L;
                        prev_R <= current_R;
                        index <= index + 4'd1;
                        
                        // Check if forward pass is complete
                        if (index == n) begin
                            next_state <= BACKWARD;
                            index <= n - 4'd1; // Start from last element for backward pass
                        end
                    end
                end

                BACKWARD: begin
                    if (index > 4'd0) begin
                        // Process current element in backward direction
                        current_L = (L[index] > L[index + 4'd1] - 8'd1) ? L[index] : L[index + 4'd1] - 8'd1;
                        current_R = (R[index] < R[index + 4'd1] + 8'd1) ? R[index] : R[index + 4'd1] + 8'd1;
                        
                        // Check if impossible
                        if (current_L > current_R) begin
                            impossible <= 1'b1;
                        end
                        
                        // Store updated L and R
                        L[index] <= current_L;
                        R[index] <= current_R;
                        
                        index <= index - 4'd1;
                        
                        // Check if backward pass is complete
                        if (index == 4'd0) begin
                            next_state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    if (impossible) begin
                        result <= 16'hFFFF;
                        // Clear s_prime_arr
                        for (i = 0; i < 16; i = i + 1) begin
                            s_prime_arr[i] <= 8'd0;
                        end
                    end else begin
                        total_demolition <= 16'd0;
                        // Compute s'[i] = R[i] and total demolition
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                s_prime_arr[i] <= R[i];
                                total_demolition <= total_demolition + (R[i] - s_arr[i]);
                            end else begin
                                s_prime_arr[i] <= 8'd0;
                            end
                        end
                        result <= total_demolition;
                    end
                    next_state <= DONE_STATE;
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