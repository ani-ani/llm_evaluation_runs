module prod_signs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [2:0] len,
    output reg signed [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] idx;
    reg signed [1:0] sign_prod;
    reg signed [15:0] mag_sum;
    reg signed [15:0] abs_val;
    reg [7:0] current_elem;
    
    // Combinational logic for sign extraction
    wire signed [1:0] current_sign;
    assign current_sign = (current_elem == 8'd0) ? 2'd0 :
                          (current_elem[7] == 1'b0) ? 2'd1 : 2'd3; // -1 in 2's complement is 2'b11

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            valid <= 1'b0;
            idx <= 3'd0;
            sign_prod <= 2'sd1; // Default neutral value
            mag_sum <= 16'sd0;
            current_elem <= 8'd0;
            abs_val <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 16'sd0;
                    idx <= 3'd0;
                    
                    if (start) begin
                        if (len == 3'd0) begin
                            // Empty array case
                            state <= DONE;
                            valid <= 1'b0;
                            result <= 16'sd0;
                            sign_prod <= 2'sd1;
                            mag_sum <= 16'sd0;
                        end else begin
                            // Initialize for processing
                            state <= PROCESS;
                            sign_prod <= 2'sd1;
                            mag_sum <= 16'sd0;
                            current_elem <= arr[0];
                        end
                    end
                end
                
                PROCESS: begin
                    // Process current element
                    // Calculate absolute value
                    if (current_elem[7]) begin
                        // Negative: 2's complement absolute value
                        abs_val <= {8'd0, (~current_elem + 8'd1)};
                    end else begin
                        // Positive or zero
                        abs_val <= {8'd0, current_elem};
                    end
                    
                    // Update magnitude sum
                    mag_sum <= mag_sum + abs_val;
                    
                    // Update sign product
                    if (current_elem == 8'd0) begin
                        sign_prod <= 2'sd0;
                    end else if (sign_prod != 2'sd0) begin
                        // Multiply current sign with product
                        if (current_sign == 2'd3) begin // current is negative (-1)
                            sign_prod <= -sign_prod;
                        end
                        // if current_sign == 2'd1 (positive), sign_prod stays same
                    end
                    // if sign_prod is already 0, it stays 0
                    
                    // Increment index
                    idx <= idx + 3'd1;
                    
                    // Check if done processing
                    if (idx == len - 3'd1) begin
                        state <= DONE;
                        // Prepare result
                        if (sign_prod == 2'sd0) begin
                            result <= 16'sd0;
                        end else if (sign_prod == 2'sd1) begin
                            result <= mag_sum;
                        end else begin // sign_prod == 2'sd3 (-1)
                            result <= -mag_sum;
                        end
                    end else begin
                        // Load next element
                        current_elem <= arr[idx + 3'd1];
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule