module even_odd_count(
    input clk,
    input rst_n,
    input start,
    input signed [31:0] num,
    output reg [3:0] even_count,
    output reg [3:0] odd_count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg signed [31:0] current_num;
    reg signed [31:0] abs_num;
    reg [3:0] digit;
    reg processing_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            even_count <= 4'd0;
            odd_count <= 4'd0;
            done <= 1'b0;
            current_num <= 32'sd0;
            abs_num <= 32'sd0;
            digit <= 4'd0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    even_count <= 4'd0;
                    odd_count <= 4'd0;
                    processing_done <= 1'b0;
                    
                    if (start) begin
                        // Load input number and take absolute value
                        if (num[31]) begin
                            // Negative number: convert to positive (handle min_int separately)
                            if (num == 32'sh80000000) begin
                                // Special case: -2147483648
                                abs_num <= 32'sd2147483648;
                            end else begin
                                abs_num <= -num;
                            end
                        end else begin
                            abs_num <= num;
                        end
                        current_num <= num; // Will be updated in PROCESSING
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Update current_num based on abs_num or previous value
                    if (current_num == num && num[31]) begin
                        // First cycle after start with negative number
                        if (num == 32'sh80000000) begin
                            current_num <= 32'sd2147483648;
                        end else begin
                            current_num <= -num;
                        end
                    end
                    
                    // Check if processing is done
                    if (current_num == 32'sd0 && abs_num == 32'sd0) begin
                        // This shouldn't happen unless num was 0 on start
                        if (num == 32'sd0) begin
                            even_count <= 4'd1; // 0 is even
                            odd_count <= 4'd0;
                            processing_done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end else if (current_num == 32'sd0 && processing_done == 1'b0) begin
                        // Finished processing all digits
                        state <= DONE_STATE;
                        processing_done <= 1'b1;
                    end else if (processing_done == 1'b0) begin
                        // Extract last digit
                        digit <= current_num % 10;
                        
                        // Check if even and increment counter
                        if ((current_num % 10) % 2 == 0) begin
                            even_count <= even_count + 4'd1;
                        end else begin
                            odd_count <= odd_count + 4'd1;
                        end
                        
                        // Divide by 10
                        current_num <= current_num / 10;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    processing_done <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    even_count <= 4'd0;
                    odd_count <= 4'd0;
                end
            endcase
        end
    end

endmodule